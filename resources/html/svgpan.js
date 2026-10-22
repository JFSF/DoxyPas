/* Pan (drag) and zoom (wheel) of a graph: the script that INTERACTIVE_SVG puts into the SVG images of the graphs. */
(function () {
  var svg = document.documentElement;
  var NS = svg.namespaceURI;
  var vp = document.createElementNS(NS, 'g');
  vp.setAttribute('id', 'viewport');
  var kids = Array.prototype.slice.call(svg.childNodes).filter(function (n) {
    return n.nodeType === 1 && !/^(script|title|defs|style|metadata)$/.test(n.localName);
  });
  svg.appendChild(vp);
  kids.forEach(function (k) { vp.appendChild(k); });

  var scale = 1, tx = 0, ty = 0, drag = null;

  function apply() {
    vp.setAttribute('transform', 'translate(' + tx + ',' + ty + ') scale(' + scale + ')');
  }

  function point(e) {
    var p = svg.createSVGPoint();
    p.x = e.clientX;
    p.y = e.clientY;
    return p.matrixTransform(svg.getScreenCTM().inverse());
  }

  svg.addEventListener('wheel', function (e) {
    e.preventDefault();
    var p = point(e);
    var ns = Math.min(20, Math.max(0.2, scale * (e.deltaY < 0 ? 1.2 : 1 / 1.2)));
    var k = ns / scale;
    tx = p.x - (p.x - tx) * k;
    ty = p.y - (p.y - ty) * k;
    scale = ns;
    apply();
  }, { passive: false });

  svg.addEventListener('mousedown', function (e) {
    if (e.button !== 0) return;
    var p = point(e);
    drag = { x: p.x, y: p.y, tx: tx, ty: ty };
    e.preventDefault();
  });

  svg.addEventListener('mousemove', function (e) {
    if (!drag) return;
    var p = point(e);
    tx = drag.tx + (p.x - drag.x);
    ty = drag.ty + (p.y - drag.y);
    apply();
  });

  window.addEventListener('mouseup', function () { drag = null; });
})();
