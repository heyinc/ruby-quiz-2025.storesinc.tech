// @ts-ignore
import { IRB } from "./irb-worker";
import { makeJQueryTerminal } from "./terminals/jquery-terminal"
import { makeXTermTerminal } from "./terminals/xterm";
import { makeXtermPtyTerminal } from "./terminals/xterm-pty";
import irb_3_4_wasm from "../node_modules/@ruby/3.4-wasm-wasi/dist/ruby.debug+stdlib.wasm?url";

function makeTerminal(rubyVersion: string) {
    const query = new URLSearchParams(window.location.search);
    const defaultTerminal = {
        // FIXME: irb (or reline?) in 3.3.3 seems not working well with xterm-pty
        "3.3": "jquery-terminal",
    }[rubyVersion] || "xterm-pty";
    const key = query.get("FEATURE_TERMINAL") || defaultTerminal;
    const terminals = {
        "xterm": makeXTermTerminal,
        "xterm-pty": makeXtermPtyTerminal,
        "jquery-terminal": makeJQueryTerminal,
    }
    if (terminals[key]) {
        return terminals[key]();
    }
    // If invalid terminal key is provided, fallback to default terminal
    return terminals[defaultTerminal]();
}

const rubyVersions = { "3.4": irb_3_4_wasm };
const defaultRubyVersion = "3.4";

function deriveCurrentRubyVersion() {
    return { version: defaultRubyVersion, url: rubyVersions[defaultRubyVersion] };
}

async function init() {
    const currentRubyVersion = deriveCurrentRubyVersion();
    if (visualViewport) {
        const vv = visualViewport;
        const updateViewportHeight = () => {
            document.documentElement.style.setProperty("--visual-viewport-height", `${vv.height}px`)
            globalThis.fitAddon?.fit();
        }
        vv.addEventListener("resize", updateViewportHeight);
        updateViewportHeight();
    } else {
        document.documentElement.style.setProperty("--visual-viewport-height", "100vh")
    }
    // Do not allow scrolling
    document.addEventListener("touchmove", (e) => e.preventDefault(), { passive: false });

    const irbWorker = new IRB();

    const term = makeTerminal(currentRubyVersion.version);
    // @ts-ignore
    window.irbWorker = irbWorker
    // @ts-ignore
    window.term = term;
    // @ts-ignore
    window.termEchoRaw = (str: string) => {
        term.write(str);
    }

    await irbWorker.init(term, currentRubyVersion)

    irbWorker.start();

    // Save history and .irbrc every 5 seconds
    setInterval(() => {
        irbWorker.snapshotHomeDir();
    }, 5000);
}

init()
