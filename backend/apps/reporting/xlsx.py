"""Small fixed-schema OOXML writer; every user value is a literal string.

No spreadsheet formulas, macros, links or sensitive model serialization.
"""

from io import BytesIO
from xml.etree.ElementTree import Element, SubElement, tostring
from zipfile import ZIP_DEFLATED, ZipFile


def workbook(headers, rows):
    sheet = Element("worksheet", xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main")
    data = SubElement(sheet, "sheetData")
    for number, values in enumerate([headers, *rows], start=1):
        row = SubElement(data, "row", r=str(number))
        for column, value in enumerate(values, start=1):
            cell = SubElement(row, "c", r=f"{chr(64 + column)}{number}", t="inlineStr")
            text = "" if value is None else str(value)
            # XML 1.0 cannot encode arbitrary control characters from input.
            text = "".join(
                c
                for c in text
                if c in "\t\n\r"
                or 32 <= ord(c) <= 0xD7FF
                or 0xE000 <= ord(c) <= 0xFFFD
                or 0x10000 <= ord(c) <= 0x10FFFF
            )
            SubElement(
                SubElement(cell, "is"), "t", {"{http://www.w3.org/XML/1998/namespace}space": "preserve"}
            ).text = text[:32767]
    output = BytesIO()
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        archive.writestr(
            "[Content_Types].xml",
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" '
            'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/xl/workbook.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            '<Override PartName="/xl/worksheets/sheet1.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
        )
        archive.writestr(
            "_rels/.rels",
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
            'Target="xl/workbook.xml"/></Relationships>',
        )
        archive.writestr(
            "xl/workbook.xml",
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<sheets><sheet name="Contacts" sheetId="1" r:id="rId1"/></sheets></workbook>',
        )
        archive.writestr(
            "xl/_rels/workbook.xml.rels",
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
            'Target="worksheets/sheet1.xml"/></Relationships>',
        )
        archive.writestr("xl/worksheets/sheet1.xml", tostring(sheet, encoding="utf-8", xml_declaration=True))
    return output.getvalue()
