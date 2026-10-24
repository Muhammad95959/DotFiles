import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { execFileSync, spawn } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";

interface EventCfg { sound?: boolean; notification?: boolean; command?: boolean; }
interface Cfg {
  timeout?: number;
  minDuration?: number;
  command?: { enabled?: boolean; path?: string; minDuration?: number };
  events?: Record<string, EventCfg>;
  messages?: Record<string, string>;
  sounds?: Record<string, string | null>;
}

const CONFIG = path.join(os.homedir(), ".config", "opencode", "opencode-notifier.json");
const DEFAULTS: Record<string, string> = {
  complete: "/usr/share/sounds/freedesktop/stereo/complete.oga",
  error: "/usr/share/sounds/freedesktop/stereo/dialog-error.oga",
  question: "/usr/share/sounds/freedesktop/stereo/window-question.oga",
  permission: "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga",
  session_started: "/usr/share/sounds/freedesktop/stereo/message.oga",
  user_message: "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga",
  user_cancelled: "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga",
};

function loadCfg(): Cfg {
  try { return JSON.parse(fs.readFileSync(CONFIG, "utf8")); } catch { return {}; }
}

function sessionTitle(pi: ExtensionAPI, ctx: ExtensionContext): string {
  try { const n = (pi as any).getSessionName?.(); if (typeof n === "string" && n) return n; } catch {}
  return path.basename(ctx.cwd || process.cwd());
}

function notify(title: string, message: string, cfg: Cfg, ctx: ExtensionContext): void {
  const t = String((cfg.timeout ?? 30) * 1000);
  if (process.platform === "darwin") {
    spawn("osascript", ["-e", `display notification ${JSON.stringify(message)} with title ${JSON.stringify(title)}`], { detached: true, stdio: "ignore" }).unref();
    return;
  }
  spawn("notify-send", ["-t", t, title, message], { detached: true, stdio: "ignore" }).unref();
}

function sound(key: string, cfg: Cfg): void {
  const f = cfg.sounds?.[key] ?? DEFAULTS[key];
  if (!f || !fs.existsSync(f)) return;
  const player = fs.existsSync("/usr/bin/paplay") ? "/usr/bin/paplay" : "/usr/bin/aplay";
  spawn(player, [f], { detached: true, stdio: "ignore" }).unref();
}

function runCmd(cfg: Cfg): void {
  const c = cfg.command;
  if (!c?.enabled || !c.path || !fs.existsSync(c.path)) return;
  spawn(c.path, [], { detached: true, stdio: "ignore" }).unref();
}

function dispatch(key: string, pi: ExtensionAPI, ctx: ExtensionContext, cfg: Cfg, startMs: number): void {
  const ec = cfg.events?.[key];
  if (!ec) return;
  const elapsed = Date.now() - startMs;
  if ((cfg.minDuration ?? 0) * 1000 > elapsed) return;
  const title = "Pi";
  const msg = (cfg.messages?.[key] ?? "{sessionTitle}").replace(/\{sessionTitle\}/g, sessionTitle(pi, ctx));
  if (ec.sound) sound(key, cfg);
  if (ec.notification) notify(title, msg, cfg, ctx);
  if (ec.command) {
    const cmdMin = (cfg.command?.minDuration ?? 0) * 1000;
    if (elapsed >= cmdMin) runCmd(cfg);
  }
}

export default function (pi: ExtensionAPI) {
  const cfg = loadCfg();
  let startMs = Date.now();
  let hadError = false;

  pi.on("session_start", async (_e, ctx) => {
    startMs = Date.now();
    hadError = false;
    dispatch("session_started", pi, ctx, cfg, startMs);
  });

  pi.on("agent_start", async () => { startMs = Date.now(); hadError = false; });

  pi.on("tool_result", async (e: any) => { if (e?.isError) hadError = true; });

  pi.on("agent_settled", async (e: any, ctx) => {
    if (e?.aborted) dispatch("user_cancelled", pi, ctx, cfg, startMs);
    else if (hadError) dispatch("error", pi, ctx, cfg, startMs);
    else dispatch("complete", pi, ctx, cfg, startMs);
  });

  pi.on("ui_prompt_start", async (_e: any, ctx) => {
    dispatch((_e?.kind === "confirm" ? "permission" : "question"), pi, ctx, cfg, startMs);
  });
}
