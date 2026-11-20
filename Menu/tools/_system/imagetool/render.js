// imagetool - renders card posters with Chromium's canvas (reads jpg/png/webp/bmp/ico).
// Used two ways:
//   app\0JAYSHOP.exe --imagetool <jobs.json>                  (the packaged client, see electron/main.js)
//   source\node_modules\electron\dist\electron.exe <this folder> <jobs.json>
// jobs.json: [{ "mode": "cover", "src": "<image>", "out": "<file.jpg>", "w": 920, "h": 586, "fx": 0.5, "fy": 0.5 },
//             { "mode": "icon",  "src": "<icon png>", "out": "<file.jpg>", "w": 920, "h": 586 }]
// cover = crop/resize a picture to fill the card (portrait pictures are shown whole on a blurred copy);
// icon = blurred colour wash + the icon in the middle.
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
const path = require('path');
const url = require('url');

module.exports = function run(jobsFile) {
  app.disableHardwareAcceleration();
  app.whenReady().then(async () => {
    const jobs = JSON.parse(fs.readFileSync(jobsFile, 'utf8').replace(/^﻿/, ''));
    const win = new BrowserWindow({ show: false, webPreferences: { webSecurity: false, offscreen: true } });
    await win.loadFile(path.join(__dirname, 'page.html'));
    let ok = 0;
    for (const job of jobs) {
      try {
        const data = await win.webContents.executeJavaScript(`render(${JSON.stringify({ ...job, src: url.pathToFileURL(job.src).href })})`);
        fs.mkdirSync(path.dirname(job.out), { recursive: true });
        fs.writeFileSync(job.out, Buffer.from(data.split(',')[1], 'base64'));
        ok++;
      } catch (e) {
        console.error(`FAILED ${job.out}: ${e.message}`);
      }
    }
    console.log(`imagetool: ${ok}/${jobs.length} posters`);
    app.quit();
  });
};
