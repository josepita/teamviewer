const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3333;
const ROOT = path.resolve(__dirname);

app.use(express.json({ limit: '10mb' }));

// Healthcheck (Coolify)
app.get('/health', (req, res) => res.status(200).send('ok'));

// Serve the editor
app.get('/', (req, res) => res.sendFile(path.join(ROOT, 'editor.html')));

// Serve static assets (images, css, etc.) from landings root under /files/
app.use('/files', express.static(ROOT));

// List all HTML files in immediate subdirectories
app.get('/api/files', (req, res) => {
  try {
    const result = [];
    const entries = fs.readdirSync(ROOT, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      if (entry.name.startsWith('.') || entry.name === 'node_modules') continue;
      const dirPath = path.join(ROOT, entry.name);
      let files;
      try { files = fs.readdirSync(dirPath); } catch { continue; }
      for (const file of files) {
        if (file.endsWith('.html')) {
          result.push({ dir: entry.name, file, path: `${entry.name}/${file}` });
        }
      }
    }
    res.json(result);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Read a file
app.get('/api/file', (req, res) => {
  const rel = req.query.path || '';
  const full = path.resolve(ROOT, rel);
  if (!full.startsWith(ROOT + path.sep) || rel.includes('..')) {
    return res.status(403).send('Forbidden');
  }
  try {
    res.json({ content: fs.readFileSync(full, 'utf8') });
  } catch {
    res.status(404).send('Not found');
  }
});

// Save a file
app.post('/api/file', (req, res) => {
  const { path: rel, content } = req.body || {};
  if (!rel || content === undefined) return res.status(400).send('Bad request');
  const full = path.resolve(ROOT, rel);
  if (!full.startsWith(ROOT + path.sep) || rel.includes('..')) {
    return res.status(403).send('Forbidden');
  }
  try {
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, content, 'utf8');
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.listen(PORT, () => {
  console.log(`\n  Landing Editor  →  http://localhost:${PORT}\n`);
});
