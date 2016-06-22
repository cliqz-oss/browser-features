import xml.etree.ElementTree as ET
from optparse import OptionParser

parser = OptionParser()
parser.add_option("--input-installer", dest="installer_path")
parser.add_option("--update-url", dest="update_url")

options, args = parser.parse_args()

tree = ET.parse(options.installer_path)
root = tree.getroot()
description = root.getchildren()[0]

# add an updateUrl inside description field of install.rdf

# TODO read the right namespace
update_url = ET.Element("ns1:updateURL")
update_url.text = options.update_url

description.append(update_url)

ET.ElementTree(root).write(open(options.installer_path, 'w'))