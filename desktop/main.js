const { app, BrowserWindow, shell, Menu, session } = require('electron');
const path = require('path');
const URL_APP = 'https://bunyanrealstate-commits.github.io/bunyan/';

if (!app.requestSingleInstanceLock()) { app.quit(); }
let win;
function create() {
  win = new BrowserWindow({
    width: 1280, height: 860, minWidth: 420, minHeight: 600,
    backgroundColor: '#e8e9ed', title: 'Bunyan Furnished',
    icon: path.join(__dirname, 'icon.png'), autoHideMenuBar: true,
    webPreferences: { contextIsolation: true, nodeIntegration: false, sandbox: true, partition: 'persist:bunyan' }
  });
  Menu.setApplicationMenu(null);
  const ses = session.fromPartition('persist:bunyan');
  ses.setPermissionRequestHandler((wc, perm, cb) => cb(['clipboard-read', 'clipboard-sanitized-write', 'notifications', 'fullscreen'].includes(perm)));
  win.loadURL(URL_APP);
  const ext = (u) => !u.startsWith(URL_APP);
  win.webContents.setWindowOpenHandler(({ url }) => { if (ext(url)) { shell.openExternal(url); } return { action: 'deny' }; });
  win.webContents.on('will-navigate', (e, url) => { if (ext(url) && !url.startsWith('file:')) { e.preventDefault(); shell.openExternal(url); } });
  win.webContents.on('did-fail-load', (e, code, desc, url, isMain) => { if (isMain && code !== -3) win.loadFile(path.join(__dirname, 'offline.html')); });
  win.on('page-title-updated', (e) => e.preventDefault());
}
app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.focus(); } });
app.whenReady().then(create);
app.on('window-all-closed', () => app.quit());
