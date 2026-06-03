import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class SanitizedEmailHtml {
  const SanitizedEmailHtml({
    required this.html,
    required this.blockedRemoteContentCount,
    required this.removedUnsafeContentCount,
  });

  final String html;
  final int blockedRemoteContentCount;
  final int removedUnsafeContentCount;

  bool get hasBlockedRemoteContent => blockedRemoteContentCount > 0;
}

SanitizedEmailHtml sanitizeEmailHtml(
  String html, {
  bool loadRemoteContent = false,
}) {
  final fragment = html_parser.parseFragment(html);
  final context = _SanitizerContext(loadRemoteContent: loadRemoteContent);

  for (final node in fragment.nodes.toList()) {
    _sanitizeNode(node, context);
  }

  return SanitizedEmailHtml(
    html: fragment.outerHtml.trim(),
    blockedRemoteContentCount: context.blockedRemoteContentCount,
    removedUnsafeContentCount: context.removedUnsafeContentCount,
  );
}

bool isSafeEmailLink(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith('#')) return true;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  if (!uri.hasScheme) return false;
  return _safeLinkSchemes.contains(uri.scheme.toLowerCase());
}

const _safeLinkSchemes = {'http', 'https', 'mailto', 'tel'};

const _safeInlineImageSchemes = {'cid', 'data'};

const _dangerousElements = {
  'applet',
  'audio',
  'base',
  'button',
  'canvas',
  'embed',
  'form',
  'iframe',
  'input',
  'link',
  'math',
  'meta',
  'object',
  'option',
  'script',
  'select',
  'source',
  'style',
  'svg',
  'textarea',
  'track',
  'video',
};

const _resourceAttributes = {
  'background',
  'href',
  'poster',
  'src',
  'srcset',
  'xlink:href',
};

const _removedAttributes = {'action', 'formaction', 'ping', 'srcdoc'};

final _dangerousStylePattern = RegExp(
  r'(url\s*\(|expression\s*\(|@import|behavior\s*:|-moz-binding\s*:)',
  caseSensitive: false,
);

class _SanitizerContext {
  _SanitizerContext({required this.loadRemoteContent});

  final bool loadRemoteContent;
  int blockedRemoteContentCount = 0;
  int removedUnsafeContentCount = 0;
}

void _sanitizeNode(dom.Node node, _SanitizerContext context) {
  if (node is dom.Comment) {
    node.remove();
    return;
  }

  if (node is! dom.Element) {
    return;
  }

  final elementName = node.localName?.toLowerCase() ?? '';
  if (_dangerousElements.contains(elementName)) {
    context.removedUnsafeContentCount++;
    node.remove();
    return;
  }

  _sanitizeAttributes(node, elementName, context);

  for (final child in node.nodes.toList()) {
    _sanitizeNode(child, context);
  }
}

void _sanitizeAttributes(
  dom.Element element,
  String elementName,
  _SanitizerContext context,
) {
  for (final attributeKey in element.attributes.keys.toList()) {
    final attributeName = attributeKey.toString();
    final lowerName = attributeName.toLowerCase();
    final value = element.attributes[attributeKey] ?? '';

    if (lowerName.startsWith('on') || _removedAttributes.contains(lowerName)) {
      context.removedUnsafeContentCount++;
      element.attributes.remove(attributeKey);
      continue;
    }

    if (lowerName == 'style') {
      final sanitized = _sanitizeStyle(value, elementName: elementName);
      if (sanitized == null) {
        element.attributes.remove(attributeKey);
      } else {
        element.attributes[attributeKey] = sanitized;
      }
      continue;
    }

    if (!_resourceAttributes.contains(lowerName)) {
      continue;
    }

    if (lowerName == 'href' || lowerName == 'xlink:href') {
      if (!_isSafeHref(value)) {
        context.removedUnsafeContentCount++;
        element.attributes.remove(attributeKey);
      }
      continue;
    }

    if (lowerName == 'srcset') {
      final sanitized = _sanitizeSrcset(value, context);
      if (sanitized == null) {
        element.attributes.remove(attributeKey);
      } else {
        element.attributes[attributeKey] = sanitized;
      }
      continue;
    }

    if (!_isSafeResourceUrl(value, context.loadRemoteContent)) {
      if (_isRemoteResourceUrl(value)) {
        context.blockedRemoteContentCount++;
        if (elementName == 'img') {
          element.attributes['alt'] = _fallbackAltText(
            element.attributes['alt'],
          );
        }
      } else {
        context.removedUnsafeContentCount++;
      }
      element.attributes.remove(attributeKey);
    }
  }

  if (elementName == 'img') {
    element.attributes.remove('width');
    element.attributes.remove('height');
  }
}

String? _sanitizeStyle(String value, {required String elementName}) {
  final safeParts = <String>[];
  for (final declaration in value.split(';')) {
    final trimmed = declaration.trim();
    if (trimmed.isEmpty) continue;
    final property = trimmed.split(':').first.trim().toLowerCase();
    if (elementName == 'img' && (property == 'width' || property == 'height')) {
      continue;
    }
    if (_dangerousStylePattern.hasMatch(trimmed)) {
      continue;
    }
    safeParts.add(trimmed);
  }
  if (safeParts.isEmpty) return null;
  return safeParts.join('; ');
}

String? _sanitizeSrcset(String value, _SanitizerContext context) {
  final safeEntries = <String>[];
  for (final entry in value.split(',')) {
    final trimmed = entry.trim();
    if (trimmed.isEmpty) continue;
    final parts = trimmed.split(RegExp(r'\s+'));
    final url = parts.first;
    if (_isSafeResourceUrl(url, context.loadRemoteContent)) {
      safeEntries.add(trimmed);
    } else if (_isRemoteResourceUrl(url)) {
      context.blockedRemoteContentCount++;
    } else {
      context.removedUnsafeContentCount++;
    }
  }
  if (safeEntries.isEmpty) return null;
  return safeEntries.join(', ');
}

bool _isSafeHref(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('#')) return true;
  return isSafeEmailLink(trimmed);
}

bool _isSafeResourceUrl(String value, bool loadRemoteContent) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  if (_isRemoteResourceUrl(trimmed)) {
    return loadRemoteContent;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  if (!uri.hasScheme) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'data') {
    return trimmed.toLowerCase().startsWith('data:image/');
  }
  return _safeInlineImageSchemes.contains(scheme);
}

bool _isRemoteResourceUrl(String value) {
  final trimmed = value.trim().toLowerCase();
  if (trimmed.startsWith('//')) return true;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return false;
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

String _fallbackAltText(String? current) {
  final trimmed = current?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  return '[remote image blocked]';
}
