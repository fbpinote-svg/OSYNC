// Set-ExeInfo.mjs - put the shop name into the .exe version info (Task Manager / file properties show it instead of "Electron").
// Run with Electron as Node (Build-App.ps1 does this):
//   set ELECTRON_RUN_AS_NODE=1 & electron.exe Set-ExeInfo.mjs <exe> <name> <source\node_modules>
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [exe, name, modules] = process.argv.slice(2);
if (!exe || !name || !modules) { console.error('usage: Set-ExeInfo.mjs <exe> <name> <node_modules>'); process.exit(2); }
const ResEdit = await import(pathToFileURL(path.join(modules, 'resedit', 'dist', 'index.js')).href);

// a freshly copied .exe is often still held by antivirus for a few seconds: retry
const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
function retry(what, fn) {
  for (let i = 1; ; i++) {
    try { return fn(); }
    catch (e) {
      if (i >= 20 || !['EBUSY', 'EPERM', 'EACCES'].includes(e.code)) { console.log(`exe info FAILED (${what}): ${e.message}`); process.exit(1); }
      sleep(1500);
    }
  }
}
const exeObj = ResEdit.NtExecutable.from(retry('read', () => fs.readFileSync(exe)), { ignoreCert: true });
const res = ResEdit.NtExecutableResource.from(exeObj);
const infos = ResEdit.Resource.VersionInfo.fromEntries(res.entries);
if (!infos.length) { console.error('no version info in ' + exe); process.exit(1); }
const vi = infos[0];
const file = path.basename(exe);
for (const lang of vi.getAllLanguagesForStringValues()) {
  vi.setStringValues(lang, { FileDescription: name, ProductName: name, CompanyName: name, OriginalFilename: file, InternalName: file });
}
vi.outputToResourceEntries(res.entries);
res.outputResource(exeObj);
const out = Buffer.from(exeObj.generate());
retry('write', () => fs.writeFileSync(exe, out));
console.log(`exe info: ${name} (${file})`);
