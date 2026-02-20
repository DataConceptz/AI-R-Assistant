const fs = require('fs');

const file = 'R/R_AI_Assistant.R';
const src = fs.readFileSync(file, 'utf8');

const startMarker = 'tags$script(HTML("';
const start = src.indexOf(startMarker);
if (start < 0) {
  console.error('start marker not found');
  process.exit(1);
}

const serverMarker = '\n# Server\n';
const serverAt = src.indexOf(serverMarker, start);
if (serverAt < 0) {
  console.error('server marker not found');
  process.exit(1);
}

const block = src.slice(start + startMarker.length, serverAt);
const endAt = block.lastIndexOf('"))');
if (endAt < 0) {
  console.error('end marker not found');
  process.exit(1);
}

const js = block.slice(0, endAt);
fs.writeFileSync('tmp_embedded.js', js, 'utf8');
console.log('Extracted JS length:', js.length);
