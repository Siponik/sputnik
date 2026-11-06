const { chromium } = require('playwright'); const fs = require('fs');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1280, height: 820 } });
  for (const f of process.argv.slice(2)) {
    let h = fs.readFileSync(f, 'utf8');
    h = h.replace(/<script src="\.\/support\.js"><\/script>/, '').replace(/<\/?x-dc>/g, '').replace(/<\/?helmet>/g, '').replace(/<script type="text\/x-dc"[\s\S]*?<\/script>/, '');
    await p.setContent(h, { waitUntil: 'networkidle' }).catch(()=>{});
    await p.screenshot({ path: f.replace(/.*\//, __dirname + '/../png/').replace('.dc.html', '.png') });
  }
  await b.close();
})();
