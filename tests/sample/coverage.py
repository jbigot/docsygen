"""List the description elements of compound.xsd that the sample's XML never uses.

Usage: python3 -I coverage.py XMLDIR
The elements are those of the docCmdGroup and docTitleCmdGroup groups (the entities included,
since Doxygen writes them into the compound.xsd next to its output) and of descriptionType.
Exit 1 if any element outside the allowlist is missing.
"""
import os, sys
import xml.etree.ElementTree as ET

XSD = '{http://www.w3.org/2001/XMLSchema}'

# Elements the sample does not need, with the reason.
ALLOWED = {
    'manonly': 'output-specific: the XML generator drops it',
    'rtfonly': 'output-specific: the XML generator drops it',
    'docbookonly': 'output-specific: the XML generator drops it',
    'xmlonly': 'output-specific: its content is copied into the XML as is',
    'msc': 'needs mscgen at Doxygen time; out of scope',
    'mscfile': 'needs mscgen at Doxygen time; out of scope',
    'diafile': 'needs dia at Doxygen time; out of scope',
    'plantuml': 'needs PlantUML at Doxygen time; out of scope',
    'plantumlfile': 'needs PlantUML at Doxygen time; out of scope',
    'dotfile': 'needs a .dot file and dot at Doxygen time',
    'dot': 'the oracle runs with HAVE_DOT=NO, as PDI does, and Doxygen then drops \\dot',
    'language': 'Doxygen 1.15 never writes it: \\~ is resolved while scanning comments',
    'copydoc': 'Doxygen 1.15 never writes it: \\copydoc is expanded while scanning comments',
}


def schema_elements(xsd):
    root = ET.parse(xsd).getroot()
    names = set()
    for group in root.findall(XSD + 'group'):
        if group.get('name') in ('docTitleCmdGroup', 'docCmdGroup'):
            names |= {e.get('name') for e in group.iter(XSD + 'element')}
    for ctype in root.findall(XSD + 'complexType'):
        if ctype.get('name') == 'descriptionType':
            names |= {e.get('name') for e in ctype.iter(XSD + 'element')}
    return names


def used_elements(xmldir):
    used = set()
    for name in os.listdir(xmldir):
        if name.endswith('.xml'):
            used |= {e.tag for e in ET.parse(os.path.join(xmldir, name)).iter()}
    return used


xmldir = sys.argv[1]
missing = sorted(schema_elements(os.path.join(xmldir, 'compound.xsd')) - used_elements(xmldir) - ALLOWED.keys())
for name in missing:
    print('MISSING', name)
print(f'{len(missing)} description elements missing from {xmldir}')
sys.exit(1 if missing else 0)
