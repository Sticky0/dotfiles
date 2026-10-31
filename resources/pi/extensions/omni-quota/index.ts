import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "fs";
import { homedir } from "os";

const MIN_INTERVAL_MS = 300000;
const BAR_CELLS = 8;

function readOmniProvider(): any {
	const base = process.env.PI_HOME || `${homedir()}/.pi/agent`;
	return JSON.parse(readFileSync(`${base}/models.json`, "utf8"))?.providers?.omni;
}

async function get(root: string, apiKey: string, path: string): Promise<any> {
	const res = await fetch(`${root}${path}`, {
		headers: apiKey ? { Authorization: `Bearer ${apiKey}` } : {},
		signal: AbortSignal.timeout(15000),
	});
	if (!res.ok) throw new Error(`${path}: ${res.status}`);
	return res.json();
}

function windowName(key: string, q: any): string {
	const name = String(q.displayName || key);
	const m = name.match(/\((\w+)\)/);
	return m ? m[1] : name;
}

function age(usage: any): string {
	if (!usage._stale || !usage._staleSince) return "";
	const min = Math.round((Date.now() - new Date(usage._staleSince).getTime()) / 60000);
	return min >= 2 ? ` (hace ${min} min)` : "";
}

function remainingPct(q: any): number | undefined {
	return q.remainingPercentage ?? (q.total ? (q.remaining / q.total) * 100 : undefined);
}

function bar(theme: any, pct: number | undefined): string {
	if (pct === undefined) return theme.fg("dim", "░".repeat(BAR_CELLS));
	const filled = Math.max(0, Math.min(BAR_CELLS, Math.ceil((pct / 100) * BAR_CELLS)));
	const color = pct > 50 ? "success" : pct > 20 ? "warning" : "error";
	return theme.fg(color, "█".repeat(filled)) + theme.fg("dim", "░".repeat(BAR_CELLS - filled));
}

function resetIn(q: any): string {
	if (!q.resetAt) return "";
	const min = Math.ceil((new Date(q.resetAt).getTime() - Date.now()) / 60000);
	if (!(min > 0)) return "";
	const d = Math.floor(min / 1440);
	const h = Math.floor((min % 1440) / 60);
	const m = min % 60;
	return d ? `${d}d ${h}h` : h ? `${h}h ${m}m` : `${m}m`;
}

function summarize(theme: any, provider: string, usage: any): string {
	const parts = Object.entries(usage.quotas || {}).map(([key, q]: [string, any]) => {
		const name = windowName(key, q).split(" / ").pop();
		const reset = resetIn(q);
		return `${theme.fg("muted", name)} ${bar(theme, remainingPct(q))}${reset ? theme.fg("dim", ` ${reset}`) : ""}`;
	});
	return `${theme.fg("muted", provider)} ${parts.join("  ") || theme.fg("dim", "sin datos")}${theme.fg("dim", age(usage))}`;
}

function detail(provider: string, usage: any): string[] {
	const lines = [`${provider}${usage.plan ? ` (${usage.plan})` : ""}${usage.limitReached ? " — LÍMITE ALCANZADO" : ""}${age(usage)}`];
	for (const [key, q] of Object.entries(usage.quotas || {}) as [string, any][]) {
		const pct = remainingPct(q);
		const reset = q.resetAt ? ` · reinicia ${new Date(q.resetAt).toLocaleString()}` : "";
		lines.push(`  ${q.displayName || key}: queda ${pct === undefined ? "?" : `${Math.round(pct)}%`} (${q.used}/${q.total})${reset}`);
	}
	if (lines.length === 1) lines.push("  sin datos de cuota");
	return lines;
}

function textWidth(s: string): number {
	return s.replace(/\x1b\[[0-9;]*m/g, "").length;
}

function show(ctx: any, text: string | undefined) {
	ctx.ui.setWidget(
		"omni-quota",
		text === undefined
			? undefined
			: () => ({
					invalidate() {},
					render: (width: number) => [" ".repeat(Math.max(0, width - textWidth(text))) + text],
				}),
		{ placement: "aboveEditor" },
	);
}

export default function (pi: ExtensionAPI) {
	let lastFetch = 0;
	let lastProvider: string | undefined;
	let last: { ctx: any; provider: string; usage: any } | undefined;

	setInterval(() => {
		if (!last) return;
		try {
			show(last.ctx, summarize(last.ctx.ui.theme, last.provider, last.usage));
		} catch {
			last = undefined;
		}
	}, 60000);

	async function providersOfCurrent(root: string, key: string, modelId: string): Promise<string[]> {
		const combos = (await get(root, key, "/v1/combos")).data || [];
		const combo = combos.find((c: any) => c.name === modelId);
		const ids: string[] = combo ? combo.models.map((m: any) => m.model).filter(Boolean) : [modelId];
		return [...new Set(ids.map((id) => id.split("/")[0]))];
	}

	async function usageOf(root: string, key: string, provider: string): Promise<any> {
		const conns = (await get(root, key, "/api/providers")).connections || [];
		const conn = conns.find((c: any) => c.provider === provider && c.isActive !== false);
		if (!conn) throw new Error(`sin conexión para ${provider}`);
		return get(root, key, `/api/usage/${conn.id}?refresh=true`);
	}

	function setup() {
		const provider = readOmniProvider();
		if (!provider) throw new Error("proveedor omni no encontrado en models.json");
		const root = (provider.baseUrl || "http://127.0.0.1:20128/v1").replace(/\/v1\/?$/, "").replace(/\/$/, "");
		return { root, key: provider.apiKey || "" };
	}

	async function refresh(ctx: any, force = false) {
		if (!force && Date.now() - lastFetch < MIN_INTERVAL_MS) return;
		lastFetch = Date.now();
		try {
			const model = ctx.model;
			if (!model || model.provider !== "omni") {
				last = undefined;
				return show(ctx, undefined);
			}
			const { root, key } = setup();
			const providers = await providersOfCurrent(root, key, model.id);
			const first = lastProvider && providers.includes(lastProvider) ? lastProvider : providers[0];
			const usage = await usageOf(root, key, first);
			last = { ctx, provider: first, usage };
			show(ctx, summarize(ctx.ui.theme, first, usage));
		} catch (e: any) {
			last = undefined;
			show(ctx, `cuota: ${e.message}`);
		}
	}

	pi.on("session_start", async (_e: any, ctx: any) => {
		await refresh(ctx, true);
	});
	pi.on("model_select", async (_e: any, ctx: any) => {
		lastProvider = undefined;
		await refresh(ctx, true);
	});
	pi.on("message_end", async (e: any, ctx: any) => {
		const m = e.message;
		if (m?.role !== "assistant") return;
		if (typeof m.responseModel === "string" && m.responseModel.includes("/")) lastProvider = m.responseModel.split("/")[0];
		await refresh(ctx);
	});

	pi.registerCommand("quota", {
		description: "Show remaining quota for the providers of the active OmniRoute combo",
		handler: async (_args: string, ctx: any) => {
			try {
				const model = ctx.model;
				if (!model || model.provider !== "omni") return ctx.ui.notify("El modelo activo no es de OmniRoute", "warning");
				const { root, key } = setup();
				const lines: string[] = [`Modelo activo: ${model.id}`];
				for (const p of await providersOfCurrent(root, key, model.id)) {
					try {
						lines.push(...detail(p, await usageOf(root, key, p)));
					} catch (e: any) {
						lines.push(`${p}: ${e.message}`);
					}
				}
				ctx.ui.notify(lines.join("\n"), "info");
				await refresh(ctx, true);
			} catch (e: any) {
				ctx.ui.notify(`omni-quota: ${e.message}`, "error");
			}
		},
	});
}
