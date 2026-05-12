### This script generates the static files needed for the proof-copilot plugins.
### It uses Jinja2 templates to adapt common agents/skills to each AI vendor.
from jinja2 import Environment, PackageLoader
import yaml
from pathlib import Path
import shutil


class VendorConfig:
    def __init__(
        self,
        name: str,
        agents_directory: str,
        skills_directory: str,
        agents_suffix: str = ".md",
        skills_suffix: str = ".md",
    ):
        self.name = name
        self.agents_directory = agents_directory
        self.skills_directory = skills_directory
        self.agents_suffix = agents_suffix
        self.skills_suffix = skills_suffix


def render_agents(env: Environment, vendor: VendorConfig):
    templates_root = "templates/agents/"
    template_suffix = ".md.j2"
    base_templates = [
        f"fstar-coder{template_suffix}",
    ]

    # Load the header information for this vendor. This information will be
    # injected as a YAML header into each generated agent file.
    headers_suffix = ".headers.yaml"
    headers_path = Path(templates_root, f"{vendor.name}{headers_suffix}")
    with open(headers_path) as f:
        headers = yaml.safe_load(f)
    print(f"Loaded headers for {vendor.name}: {headers}")

    for base_template in base_templates:
        # Jinja2 looks under the "templates" directory by default, so we drop
        # that prefix from the templates root.
        base_template_path = Path(
            templates_root.removeprefix("templates/"), base_template
        )
        template = env.get_template(base_template_path.as_posix())
        rendered = template.render(headers=headers)
        output_filename = (
            base_template.removesuffix(template_suffix) + vendor.agents_suffix
        )
        output_path = Path(vendor.agents_directory, output_filename)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w") as f:
            f.write(rendered)


def render_skills(env: Environment, vendor: VendorConfig):
    # Currently the skills don't need any vendor-specific information so we just copy them over.
    skills_root = "templates/skills/"
    # The copy operation returns an error if the destination directory already exists, so we remove it first if needed.
    if Path(vendor.skills_directory).exists():
        shutil.rmtree(vendor.skills_directory, ignore_errors=True)
    Path(skills_root).copy(vendor.skills_directory)


def render_vendor_files(env: Environment, vendor: VendorConfig):
    render_agents(env, vendor)
    render_skills(env, vendor)


if __name__ == "__main__":
    # The PackageLoader looks for templates in the "templates" directory of the
    # given module. When given a python file, it will look for a "templates"
    # directory in the same directory as that file. So in this case, it will
    # look for templates in "./templates/"
    env = Environment(
        loader=PackageLoader("generate_plugins"),
        # Strip out the trailing newlines that jinja expressions add when rendering templates to make the output cleaner.
        #
        # Without this option, the rendered headers have extra newlines between each key-value pair.
        trim_blocks=True,
    )

    # List of AI vendors to generate plugins for. Templates are expected to be
    # found under the "templates" directory with prefixes matching these vendor
    # names (e.g., "copilot.headers.yaml").
    vendors = [
        VendorConfig(
            "copilot",
            "out/copilot/plugins/proof-copilot/agents/",
            "out/copilot/plugins/proof-copilot/skills/",
            agents_suffix=".agent.md",
        ),
        VendorConfig(
            "claude",
            "out/claude/plugins/proof-copilot/agents/",
            "out/claude/plugins/proof-copilot/skills/",
        ),
    ]

    for vendor in vendors:
        render_vendor_files(env, vendor)
