const esbuild = require("esbuild");
const path = require("path");

esbuild.build({
  entryPoints: [path.join(__dirname, "src/index.ts")],
  bundle: true,
  format: "iife",
  outfile: path.join(__dirname, "../SNESStudio/Resources/CodeMirror/editor.js"),
  minify: true,
  sourcemap: false,
  target: ["safari17"],
  define: {
    "process.env.NODE_ENV": '"production"',
  },
}).then(() => {
  console.log("CodeMirror bundle built successfully");
}).catch((err) => {
  console.error(err);
  process.exit(1);
});
