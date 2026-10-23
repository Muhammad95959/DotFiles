import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		// Track thinking level from events
		let thinkingLevel = "high";


		pi.on("thinking_level_select", async (event) => {
			thinkingLevel = event.level;
		});

		// Track tokens/sec for the most recent assistant response
		let lastSpeed: number | null = null;
		let currentTps: number | null = null;
		let isStreaming = false;
		let assistantStartTime: number | null = null;
		let mcpSnapshot: any = null;
		let requestRender: (() => void) | null = null;

		pi.on("message_start", async (event) => {
			if (event.message.role === "assistant") {
				assistantStartTime = Date.now();
				isStreaming = true;
				currentTps = null;
			}
		});

		pi.on("message_update", async (event) => {
			if (!isStreaming || !assistantStartTime) return;
			const partial = (event as any)?.assistantMessageEvent?.partial;
			const outputTokens = partial?.usage?.output;
			const elapsed = (Date.now() - assistantStartTime) / 1000;
			if (outputTokens && outputTokens > 0 && elapsed > 0.1) {
				currentTps = Math.round(outputTokens / elapsed);
			}
		});

		pi.on("message_end", async (event) => {
			if (event.message.role === "assistant") {
				const m = event.message as AssistantMessage;
				const outputTokens = m.usage.output;
				const elapsed = assistantStartTime ? (Date.now() - assistantStartTime) / 1000 : 0;

				// Skip if elapsed is unreasonably small (e.g. restored from session)
				if (elapsed > 0.5 && outputTokens > 0) {
					lastSpeed = Math.round(outputTokens / elapsed);
				}
				isStreaming = false;
				currentTps = null;
				assistantStartTime = null;
			}
		});

		// Subscribe to MCP status snapshots published by pi-mcp-adapter
		pi.events.on("pi-mcp-adapter/status/v1", (snap: any) => {
			mcpSnapshot = snap;
			requestRender?.();
		});

		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsub = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose: unsub,
				invalidate() {},
				render(width: number): string[] {
					let input = 0,
						output = 0,
						cost = 0,
						reasoning = 0;
					for (const e of ctx.sessionManager.getBranch()) {
						if (e.type === "message" && e.message.role === "assistant") {
							const m = e.message as AssistantMessage;
							input += m.usage.input;
							output += m.usage.output;
							cost += m.usage.cost.total;
							reasoning += m.usage.reasoningTokens ?? 0;
						}
					}

					const fmt = (n: number) => {
						if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
						if (n >= 1000) return `${(n / 1000).toFixed(1)}k`;
						return `${n}`;
					};

					// Separator
					const sep = " " + theme.fg("dim", "│") + " ";

					// Session context usage — model's context window
					const contextUsage = ctx.getContextUsage();
					const ctxLimit = contextUsage?.limit ?? ctx.model?.contextWindow ?? 0;
					const ctxTokens = contextUsage?.tokens ?? 0;
					let contextPct = "";
					if (ctxLimit > 0) {
						const pct = (ctxTokens / ctxLimit) * 100;
						const color = pct > 80 ? "error" : pct > 50 ? "warning" : "success";
						contextPct = theme.fg(color, `${pct.toFixed(1)}%`) + theme.fg("dim", "/" + fmt(ctxLimit));
					}

					const branch = footerData.getGitBranch();

					// Colored stat labels — using valid theme token names only
					const arrowUp = theme.fg("success", "↑") + theme.fg("text", fmt(input));
					const arrowDown = theme.fg("error", "↓") + theme.fg("text", fmt(output));
					const reasoningStr = reasoning > 0
						? theme.fg("accent", "R") + theme.fg("text", fmt(reasoning))
						: "";
					const costStr = theme.fg("warning", "$" + cost.toFixed(3));
					const speedValue = isStreaming && currentTps !== null ? currentTps : lastSpeed;
					const speedStr = theme.fg("mdLink", (speedValue !== null ? fmt(speedValue) : "--") + " t/s");

					// Thinking level dot colors — using valid tokens
					const levelColors: Record<string, string> = {
						off: "thinkingOff",
						minimal: "thinkingMinimal",
						low: "thinkingLow",
						medium: "thinkingMedium",
						high: "thinkingHigh",
						"extra-high": "thinkingXhigh",
					};
					const levelColor = levelColors[thinkingLevel] || "accent";
					const levelDot = theme.fg(levelColor, "●");
					const modelStr = theme.fg("accent", ctx.model?.id || "no-model");
					const levelStr = theme.fg("muted", thinkingLevel);

					// Git branch — use success color
					const gitStr = branch ? theme.fg("toolDiffAdded", " " + branch) : "";

					// ===== LEFT: stats with │ separators between each =====
					const leftParts = [
						arrowUp,
						arrowDown,
						reasoningStr,
						costStr,
						contextPct,
						speedStr,
					].filter(Boolean);

					const left = leftParts.join(sep);

					// MCP status
					let mcpStr = "";
					if (mcpSnapshot && Array.isArray(mcpSnapshot.servers) && mcpSnapshot.servers.length > 0) {
						const connected = mcpSnapshot.connectedCount ?? 0;
						const total = mcpSnapshot.servers.length;
						mcpStr = theme.fg("muted", `MCP ${connected}/${total}`);
					}

					// ===== RIGHT: model info =====
					const rightParts = [
						modelStr,
						levelDot + " " + levelStr,
						gitStr,
						mcpStr,
					].filter(Boolean);

					const right = rightParts.join(" " + theme.fg("dim", "•") + " ");
					const midSep = "";

					const rawCwd = ctx.cwd || process.cwd();
					const home = process.env.HOME || "";
					const displayCwd = home && rawCwd.startsWith(home)
						? "~" + rawCwd.slice(home.length)
						: rawCwd;
					const cwdStr = theme.fg("muted", displayCwd);

					const leftContent = left + midSep;
					const cwdWidth = visibleWidth(cwdStr);
					const centerStart = Math.max(0, Math.floor((width - cwdWidth) / 2));
					let safeLeft = leftContent;
					if (visibleWidth(safeLeft) > centerStart) {
						safeLeft = truncateToWidth(safeLeft, Math.max(0, centerStart - 1));
					}
					const leftPad = " ".repeat(Math.max(0, centerStart - visibleWidth(safeLeft)));

					const rightWidth = visibleWidth(right);
					const rightStart = Math.max(centerStart + cwdWidth, width - rightWidth - 1);
					const midPad = " ".repeat(Math.max(1, rightStart - (centerStart + cwdWidth)));

					return [truncateToWidth(" " + safeLeft + leftPad + cwdStr + midPad + right + " ", width)];
				},
			};
		});
	});
}
