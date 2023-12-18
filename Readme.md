### Commandbox-ssg

A static site generator implemented in CommandBox

### Installation

```bash
box install commandbox-ssg
```

### Getting Started (Quick)

```bash
box
mkdir my-test-site --cd
echo "### Hello from commandbox-ssg" > index.md
ssg build
```

### Changelog

0.0.5
- Adding `view` attribute to specify how a template is rendered irregardless of type. If view is not spcified it will fall back to `type`
- ColdFusion templates will now honor `view` or `type` attributes when rendering
- Adding `ssg_state` variable that monitors folder structure and which layouts/includes exist.