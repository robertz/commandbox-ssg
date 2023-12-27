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
- Adding `ssg_state` variable that monitors folder structure and which layouts/includes exist

0.0.6
- Adding `ssg serve` command that writes out the required `.htaccess` and `server.json` to serve static content if not already present. Also starts a static web server to see your changes.
- Clean up commands formatting and comments

0.0.7
- Correcting `ssg init` behavior when scaffolding application. It should work properly on Windows now.

0.0.8
- `/_includes` directory will is automatically excluded

0.0.9
- CSS ad JS files are now monitored by `ssg watch` command and will trigger a build when a change is detected
- Use `find` instead of `contains` when checking layout/view arrays to determine if the item exists

0.0.10
- Much of the `build` command has been restructured to get pagination working.
- Simple pagination working now (pageSize of 1).
- Files are now output based on `prc.outFile` and not by directory structure and fileSlug
- If a template has the `pagination` flag it will be removed from `collections.all`. Only renedered templates are retained
- Code cleanup
