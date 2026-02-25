const fs = require('fs');
const src = fs.readFileSync('R/R_AI_Assistant.R', 'utf8');

// Find all tags$script(HTML("...")) blocks
const re = /tags\$script\(HTML\("([\s\S]*?)"\)\)/g;
let match;
let idx = 0;
while ((match = re.exec(src)) !== null) {
  idx++;
  let js = match[1];
  // R string: \\" becomes \" at runtime, which in JS is just "
  // The raw file has \\\" which in R source is \\ + \" = \ + "
  // So the R runtime string has \" which browser sees as \"
  // For syntax check: replace \\\" with \"
  js = js.replace(/\\\\\\"/g, '\\"');
  try {
    new Function(js);
    console.log('Script block ' + idx + ': SYNTAX OK (' + js.length + ' chars)');
  } catch(e) {
    console.log('Script block ' + idx + ': SYNTAX ERROR: ' + e.message);
    // Show context around error
    var lines = js.split('\n');
    if (e.message.match(/line (\d+)/i)) {
      var lineNum = parseInt(RegExp.$1);
      for (var i = Math.max(0, lineNum - 3); i < Math.min(lines.length, lineNum + 2); i++) {
        console.log((i + 1) + (i + 1 === lineNum ? ' >>> ' : '     ') + lines[i]);
      }
    }
  }
}
if (idx === 0) console.log('No script blocks found!');
