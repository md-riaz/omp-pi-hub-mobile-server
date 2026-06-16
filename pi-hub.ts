import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createHubExtension } from "./hub-core.ts";

export default function piHubExtension(pi: ExtensionAPI) {
	return createHubExtension(pi, {
		clientName: "pi-hub-extension",
		displayName: "Pi Hub",
		tuiName: "Pi TUI",
		uiStatusKey: "pi-hub",
	});
}
