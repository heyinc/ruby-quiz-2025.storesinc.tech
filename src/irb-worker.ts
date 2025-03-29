import { RubyVM, consolePrinter } from "@ruby/wasm-wasi"
import { Term } from "./terminals/terminal";
import { Directory, File, OpenFile, PreopenDirectory, WASI, strace } from "@bjorn3/browser_wasi_shim";
import { Fd, OpenSyncOPFSFile, SyncOPFSFile } from "@bjorn3/browser_wasi_shim/typings";

import th_rb from "./ruby/th.rb?url";

export type RubyVersion = {
    version: string,
    url: string,
}

export class IRB {
    private instance: WebAssembly.Instance | null;
    private wasi: WASI;
    private vm: RubyVM;
    private isTracingSyscall = false;
    private homeDir: PreopenDirectory;
    private term: Term;

    async fetchWithProgress(url: string, title: string, termWriter: Term): Promise<Uint8Array> {
        const response = await fetch(url);
        if (!response.ok || response.body === null) {
            throw new Error(`Failed to fetch ${url}: ${response.statusText}`);
        }
	let dots = 0;
	const indicator = setInterval(() => {
	    termWriter.set_prompt(`${title} ${".".repeat(dots)}`);
	    dots = (dots + 1) % 4;
	}, 200);
	try {
	    const buffer = await response.arrayBuffer();
	    return new Uint8Array(buffer);
	} finally {
	    clearInterval(indicator);
	}
    }

    async init(termWriter: Term, rubyVersion: RubyVersion) {
        this.term = termWriter;
        const buffer = await this.fetchWithProgress(rubyVersion.url, "Downloading irb.wasm", termWriter);

        const args = [
            "irb.wasm", "-e_=0", "-EUTF-8", "-I/gems/lib"
        ];
        termWriter.set_prompt("");

        let homeContents: Map<string, Fd>;
        try {
            homeContents = await this.loadHomeDir();
        } catch {
            homeContents = new Map();
        }

        const homeDir = new PreopenDirectory("/home", new Map([
            ["me", new Directory(homeContents)]
        ]));

        const fds = [
            new OpenFile(new File([])),
            new OpenFile(new File([])),
            new OpenFile(new File([])),
            homeDir,
            new PreopenDirectory("/dev", new Map([
                ["null", new File([])],
            ]))
        ]
        const env = [
            "HOME=/home/me",
            "GEM_PATH=/gems:/home/me/.gem/ruby/3.2.0+2",
            "GEM_SPEC_CACHE=/home/me/.gem/specs",
            "TERM=xterm-256color",
        ]
        const wasi = new WASI(args, env, fds, { debug: false });
        const vm = new RubyVM();
        const printer = consolePrinter({
            stdout: termWriter.write.bind(termWriter),
            stderr: termWriter.write.bind(termWriter),
        });
        const imports = {
            wasi_snapshot_preview1: this.isTracingSyscall ? strace(wasi.wasiImport, []) : wasi.wasiImport,
        }
        printer.addToImports(imports)
        vm.addToImports(imports)
        const { instance } = await WebAssembly.instantiate(buffer, imports);
        printer.setMemory(instance.exports.memory as any);
        await vm.setInstance(instance);

        wasi.initialize(instance as any);
        (instance.exports._initialize as Function)();
        vm.initialize(args);

        this.instance = instance;
        this.wasi = wasi
        this.vm = vm;
        this.homeDir = homeDir;
    }

    async start() {
        this.vm.eval(`require "/bundle/setup"`)
        this.vm.eval(`
            # Hack to ignore "require 'io/console'" and "require 'io/wait'"
            $LOADED_FEATURES << "io/console" << "io/wait" << "socket"
            Gem::Specification.find_by_name("reline").dependencies.clear
        `)
        const thCode = await fetch(th_rb);
        this.vm.eval(await thCode.text());
        this.term.startIRB(this.vm);
    }

    async sleep_ms(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    static FILES_TO_SAVE: string[] = [
        ".irbrc",
        ".irb_history",
    ];

    async loadHomeDir() {
        const homeContents = new Map();
        const opfsRoot = await navigator.storage.getDirectory();
        for (const filePath of IRB.FILES_TO_SAVE) {
            try {
                const handle = await opfsRoot.getFileHandle(filePath, { create: false });
                if (!handle) { continue; }
                const file = await handle.getFile();
                const data = await file.arrayBuffer();
                const fileNode = new File(new Uint8Array(data));
                homeContents.set(filePath, fileNode);
            } catch {
                // ignore non-existing files
            }
        }
        return homeContents
    }

    async snapshotHomeDir() {
        this.vm.eval("IRB.conf[:MAIN_CONTEXT].io.save_history")
        const opfsRoot = await navigator.storage.getDirectory();
        const homeMe = this.homeDir.dir.contents.get("me");
        for (const file of IRB.FILES_TO_SAVE) {
            const fd = homeMe.contents.get(file)
            if (!(fd instanceof File)) { continue; }
            const handle = await opfsRoot.getFileHandle(file, { create: true });
            const writable = await handle.createWritable();
            await writable.write(fd.data);
            await writable.close();
        }
    }
}
