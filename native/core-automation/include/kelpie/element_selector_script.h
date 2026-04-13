#pragma once

#include <string>

namespace kelpie {

inline std::string ElementSelectorBuilderScript() {
  return R"JS(
function kelpieEscapeIdentifier(value) {
  if (window.CSS && typeof window.CSS.escape === 'function') {
    return window.CSS.escape(String(value));
  }
  return String(value).replace(/([ !"#$%&'()*+,./:;<=>?@[\\\]^`{|}~])/g, '\\$1');
}
function kelpieEscapeAttribute(value) {
  return String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}
function kelpieBuildSelector(node) {
  if (!node || node.nodeType !== 1) return null;
  if (node.id) return '#' + kelpieEscapeIdentifier(node.id);
  var segments = [];
  var current = node;
  while (current && current.nodeType === 1) {
    var tag = current.tagName.toLowerCase();
    var segment = tag;
    if (current.id) {
      segment += '#' + kelpieEscapeIdentifier(current.id);
      segments.unshift(segment);
      return segments.join(' > ');
    }
    var name = current.getAttribute && current.getAttribute('name');
    if (name) {
      var named = tag + '[name="' + kelpieEscapeAttribute(name) + '"]';
      try {
        if (document.querySelectorAll(named).length === 1) {
          segments.unshift(named);
          return segments.join(' > ');
        }
      } catch (error) {}
    }
    var parent = current.parentElement;
    if (parent) {
      var index = 1;
      var sibling = current;
      while ((sibling = sibling.previousElementSibling)) {
        if (sibling.tagName === current.tagName) index += 1;
      }
      segment += ':nth-of-type(' + index + ')';
    }
    segments.unshift(segment);
    var candidate = segments.join(' > ');
    try {
      if (document.querySelectorAll(candidate).length === 1) {
        return candidate;
      }
    } catch (error) {}
    current = parent;
  }
  return segments.join(' > ');
}
)JS";
}

}  // namespace kelpie
