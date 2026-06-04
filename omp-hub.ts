import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { createHubExtension } from "./hub-core.ts";

export default function ompHubExtension(omp: ExtensionAPI) {
	return createHubExtension(omp, {
		clientName: "omp-hub-extension",
		displayName: "OMP Hub",
		tuiName: "OMP TUI",
		uiStatusKey: "omp-hub",
		cliCommand: "omp",
	});
}
