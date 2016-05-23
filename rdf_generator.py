#!/usr/bin/env python
from jinja2 import Environment, FileSystemLoader

class RDFGenerator(object):

    def __init__(self, addon_id, addon_version, addon_url,
            max_version, min_version, output_path, template):
        self.template = template
        self.output_path = output_path

        self.addon_id = addon_id
        self.addon_version = addon_version
        self.addon_url = addon_url
        self.max_version = max_version
        self.min_version = min_version

    def generate(self):
        env = Environment(loader=FileSystemLoader('templates'))
        manifest_template = env.get_template(self.template)
        rdf = manifest_template.render(
            id=self.addon_id,
            version=self.addon_version,
            max_version=self.max_version,
            min_version=self.min_version,
            download_link=self.addon_url
        )

        with open(self.output_path, "wb") as f:
                f.write(rdf.encode("utf-8"))


if __name__ == '__main__':
    from optparse import OptionParser

    parser = OptionParser()
    parser.add_option("--output-path", dest="output_path")
    parser.add_option("--template", dest="template")

    parser.add_option("--addon-id", dest="addon_id")
    parser.add_option("--addon-version", dest="addon_version")
    parser.add_option("--addon-url", dest="addon_url")
    parser.add_option("--min-version", dest="min_version")
    parser.add_option("--max-version", dest="max_version")

    options, args = parser.parse_args()

    required = "addon_id addon_version addon_url min_version max_version output_path template".split()

    for r in required:
        if options.__dict__[r] is None:
            r = r.replace("_", "-")
            parser.error("parameter --%s required"%r)

    generator = RDFGenerator(**options.__dict__)
    generator.generate()
