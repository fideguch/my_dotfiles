/**
 * iOS Web Inspector — DOM Inspection Script
 *
 * Self-contained JavaScript that runs inside any browser context.
 * Captures element positions, computed styles, hierarchy, and
 * auto-detects common mobile layout issues.
 *
 * Usage (console):
 *   copy(JSON.stringify(iosWebInspect({ selector: 'header' })))
 *
 * Usage (programmatic):
 *   const result = iosWebInspect({ selector: '.my-component', maxDepth: 5 })
 */

// eslint-disable-next-line no-unused-vars
function iosWebInspect(options) {
  const opts = Object.assign({
    selector: null,
    maxDepth: 10,
    maxElements: 200,
    includeHidden: false,
    styleProperties: [
      'display', 'position', 'width', 'height',
      'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
      'padding-top', 'padding-right', 'padding-bottom', 'padding-left',
      'font-size', 'font-family', 'font-weight', 'line-height',
      'color', 'background-color',
      'border-top-width', 'border-right-width', 'border-bottom-width', 'border-left-width',
      'border-top-style', 'border-right-style', 'border-bottom-style', 'border-left-style',
      'border-radius',
      'z-index', 'overflow', 'overflow-x', 'overflow-y',
      'flex-direction', 'justify-content', 'align-items', 'flex-wrap', 'gap',
      'grid-template-columns', 'grid-template-rows',
      'opacity', 'transform', 'box-sizing',
      'top', 'left', 'right', 'bottom',
      'white-space', 'text-overflow',
      'min-width', 'max-width', 'min-height', 'max-height'
    ]
  }, options || {});

  var result = {
    meta: buildMeta(),
    elements: [],
    issues: []
  };

  var elementCount = 0;

  if (opts.selector) {
    var targets = document.querySelectorAll(opts.selector);
    for (var i = 0; i < targets.length && elementCount < opts.maxElements; i++) {
      collectElement(targets[i], 0, null);
    }
  } else {
    collectElement(document.body, 0, null);
  }

  detectIssues();

  return result;

  // --- helpers ---

  function buildMeta() {
    var mqTests = [
      '(max-width: 320px)',
      '(max-width: 375px)',
      '(max-width: 390px)',
      '(max-width: 428px)',
      '(max-width: 768px)',
      '(max-width: 1024px)',
      '(prefers-color-scheme: dark)',
      '(prefers-reduced-motion: reduce)',
      '(orientation: portrait)',
      '(orientation: landscape)'
    ];
    var mediaQueries = {};
    mqTests.forEach(function(mq) {
      mediaQueries[mq] = window.matchMedia(mq).matches;
    });

    return {
      url: location.href,
      title: document.title,
      timestamp: new Date().toISOString(),
      viewport: {
        width: window.innerWidth,
        height: window.innerHeight
      },
      scrollPosition: {
        x: window.scrollX,
        y: window.scrollY
      },
      documentSize: {
        width: document.documentElement.scrollWidth,
        height: document.documentElement.scrollHeight
      },
      devicePixelRatio: window.devicePixelRatio || 1,
      mediaQueries: mediaQueries
    };
  }

  function cssEscape(str) {
    if (typeof CSS !== 'undefined' && CSS.escape) return CSS.escape(str);
    // Fallback: escape special CSS selector characters
    return str.replace(/([!"#$%&'()*+,.\/:;<=>?@[\\\]^`{|}~])/g, '\\$1');
  }

  function buildSelector(el) {
    if (el.id) {
      return el.tagName.toLowerCase() + '#' + cssEscape(el.id);
    }
    var parts = [el.tagName.toLowerCase()];
    if (el.classList && el.classList.length > 0) {
      parts.push(
        Array.prototype.map.call(el.classList, function(c) {
          return '.' + cssEscape(c);
        }).join('')
      );
    }
    var selector = parts.join('');

    // Disambiguate if needed
    var parent = el.parentElement;
    if (parent) {
      var siblings = parent.querySelectorAll(':scope > ' + selector);
      if (siblings.length > 1) {
        var idx = Array.prototype.indexOf.call(parent.children, el) + 1;
        selector += ':nth-child(' + idx + ')';
      }
    }

    return selector;
  }

  function buildFullSelector(el) {
    var parts = [];
    var current = el;
    while (current && current !== document.body && current !== document.documentElement) {
      parts.unshift(buildSelector(current));
      current = current.parentElement;
    }
    return parts.join(' > ');
  }

  function getStyles(el) {
    var computed = window.getComputedStyle(el);
    var styles = {};
    opts.styleProperties.forEach(function(prop) {
      var val = computed.getPropertyValue(prop);
      // Skip default/unset values to reduce noise
      if (val && val !== 'none' && val !== 'normal' && val !== 'auto' &&
          val !== '0px' && val !== 'rgba(0, 0, 0, 0)' && val !== 'transparent' &&
          val !== 'static' && val !== 'visible' && val !== 'content-box') {
        styles[prop] = val;
      }
    });
    // Always include display and position
    styles['display'] = computed.getPropertyValue('display');
    styles['position'] = computed.getPropertyValue('position');
    return styles;
  }

  function isVisible(el) {
    if (opts.includeHidden) return true;
    var style = window.getComputedStyle(el);
    if (style.display === 'none') return false;
    if (style.visibility === 'hidden') return false;
    if (parseFloat(style.opacity) === 0) return false;
    var rect = el.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) return false;
    return true;
  }

  function isInteresting(el) {
    var tag = el.tagName.toLowerCase();
    // Always include semantic/interactive elements
    var interestingTags = [
      'header', 'footer', 'nav', 'main', 'section', 'article', 'aside',
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'button', 'a', 'input', 'textarea', 'select', 'form', 'label',
      'img', 'video', 'canvas', 'svg',
      'table', 'ul', 'ol', 'dialog'
    ];
    if (interestingTags.indexOf(tag) >= 0) return true;
    // Include elements with ID or meaningful classes
    if (el.id) return true;
    if (el.classList && el.classList.length > 0) return true;
    // Include elements with roles
    if (el.getAttribute('role')) return true;
    // Include elements with data attributes
    if (el.dataset && Object.keys(el.dataset).length > 0) return true;
    return false;
  }

  function getTextContent(el) {
    // Get direct text content, not children's
    var text = '';
    for (var i = 0; i < el.childNodes.length; i++) {
      if (el.childNodes[i].nodeType === 3) { // Text node
        text += el.childNodes[i].textContent;
      }
    }
    text = text.trim();
    return text.length > 100 ? text.substring(0, 100) + '...' : text;
  }

  function collectElement(el, depth, parentSel) {
    if (elementCount >= opts.maxElements) return;
    if (depth > opts.maxDepth) return;
    if (!el || el.nodeType !== 1) return;
    if (!isVisible(el)) return;

    var tag = el.tagName.toLowerCase();
    // Skip script, style, noscript, and other non-visual elements
    if (['script', 'style', 'noscript', 'link', 'meta', 'br', 'hr'].indexOf(tag) >= 0) return;

    var selector = buildFullSelector(el);
    var shouldInclude = isInteresting(el) || depth <= 2 || opts.selector;
    var rect = el.getBoundingClientRect();

    if (shouldInclude) {
      var entry = {
        tag: tag,
        id: el.id || null,
        classes: el.classList ? Array.prototype.slice.call(el.classList) : [],
        role: el.getAttribute('role') || null,
        selector: selector,
        rect: {
          x: Math.round(rect.x * 10) / 10,
          y: Math.round(rect.y * 10) / 10,
          width: Math.round(rect.width * 10) / 10,
          height: Math.round(rect.height * 10) / 10
        },
        styles: getStyles(el),
        parentSelector: parentSel,
        depth: depth,
        textContent: getTextContent(el),
        childCount: el.children.length
      };

      // Add extra attributes for interactive/form elements
      if (tag === 'a') entry.href = el.getAttribute('href');
      if (tag === 'img') {
        entry.src = el.getAttribute('src');
        entry.alt = el.getAttribute('alt');
      }
      if (tag === 'input') {
        entry.type = el.getAttribute('type');
        entry.name = el.getAttribute('name');
      }

      result.elements.push(entry);
      elementCount++;
    }

    // Recurse into children
    var children = el.children;
    for (var i = 0; i < children.length && elementCount < opts.maxElements; i++) {
      collectElement(children[i], depth + 1, selector);
    }
  }

  function detectIssues() {
    var vw = window.innerWidth;
    var vh = window.innerHeight;

    result.elements.forEach(function(el) {
      // Horizontal overflow detection
      var domEl = null;
      try {
        domEl = document.querySelector(el.selector);
      } catch (e) {
        // Invalid selector (special chars in class names) — skip DOM checks
      }
      if (domEl) {
        if (domEl.scrollWidth > domEl.clientWidth + 1) {
          result.issues.push({
            type: 'overflow-x',
            element: el.selector,
            detail: 'scrollWidth (' + domEl.scrollWidth + ') > clientWidth (' + domEl.clientWidth + ')'
          });
        }
        if (domEl.scrollHeight > domEl.clientHeight + 1 &&
            el.styles['overflow-y'] !== 'scroll' && el.styles['overflow-y'] !== 'auto' &&
            el.styles['overflow'] !== 'scroll' && el.styles['overflow'] !== 'auto') {
          result.issues.push({
            type: 'overflow-y',
            element: el.selector,
            detail: 'scrollHeight (' + domEl.scrollHeight + ') > clientHeight (' + domEl.clientHeight + '). No overflow scroll set.'
          });
        }
      }

      // Element extending beyond viewport
      if (el.rect.x + el.rect.width > vw + 1) {
        result.issues.push({
          type: 'viewport-overflow',
          element: el.selector,
          detail: 'Right edge at ' + Math.round(el.rect.x + el.rect.width) + 'px exceeds viewport width ' + vw + 'px'
        });
      }

      // Touch target too small (iOS HIG: 44x44pt minimum)
      var interactiveTags = ['button', 'a', 'input', 'select', 'textarea'];
      var isInteractive = interactiveTags.indexOf(el.tag) >= 0 ||
                         el.role === 'button' || el.role === 'link' || el.role === 'tab';
      if (isInteractive && (el.rect.width < 44 || el.rect.height < 44)) {
        result.issues.push({
          type: 'touch-target',
          element: el.selector,
          detail: Math.round(el.rect.width) + 'x' + Math.round(el.rect.height) + ' < 44x44 minimum (iOS HIG)'
        });
      }

      // Text overflow without handling
      if (domEl && el.styles['white-space'] === 'nowrap' && !el.styles['text-overflow']) {
        if (domEl.scrollWidth > domEl.clientWidth + 1) {
          result.issues.push({
            type: 'text-overflow',
            element: el.selector,
            detail: 'white-space: nowrap without text-overflow handling. Content clipped.'
          });
        }
      }
    });

    // Document-level horizontal scroll
    var docWidth = document.documentElement.scrollWidth;
    if (docWidth > vw + 1) {
      result.issues.push({
        type: 'page-overflow',
        element: 'html',
        detail: 'Page scrollWidth (' + docWidth + ') > viewport (' + vw + '). Horizontal scrollbar visible.'
      });
    }
  }
}

// Self-executing wrapper for console paste usage
// Uncomment the line below when pasting into console:
// copy(JSON.stringify(iosWebInspect({ selector: null }), null, 2));
