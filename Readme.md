### Commandbox-ssg

A static site generator implemented in CommandBox

### Source and documentation

[GitHub](https://github.com/robertz/commandbox-ssg)

[Docs](https://kisdigital.com/projects/commandbox-ssg)

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

0.2.2
- Removed `skip_beautify` flag in favor on content type detection. Only html files will be parsed using jSoup

0.2.1

- Adding `skip_beautify` front matter attribute to skip jSoup parsing. Fixes an issue where non-html files would get wrapped in html/body tags

0.2.0

- Leverage jSoup to tidy output

0.1.3

- Exclude `_site/` directory by default. This was causing issues when passthrough folders contained markdown files.
- Fixed some issues with pagination. The parent template will have `published` flag set to false.
- Render function now uses `template` cache to render pages instead of `collections.all`. The `excludeFromCollections` flag should finally work correctly.

0.1.2

- applicationHelper.cfm include path should be relative for Windows
- `onBuildReady()` event will fire once configuration has been loaded if it exists in `applicationHelper.cfm`
- `beforeProcessCollections()` event will fire once template data has been loaded but before `processCollectionsData()` is executed if it exists in `applicationHelper.cfm`
- `beforeGenerate()` event will fire after collections and pagination has been processed and before static generation if it exists in `applicationHelper.cfm`

0.1.1

- Adding applicationHelper.cfm support to be able to execute code on build and make user defined functions available when rendering pages

0.1.0

- Build command has been completely rewritten
- `publishDate` property has been renamed `date`. The value will default to lastModified time of the file unless explicitly set
- Directory handling has been normalized so paths are treated the same throughout
- Working through routines to enhances error handling and messaging
- Global data `_data/**.json` files can now be nested
- New arguemnt `--showconfig` will now output details about the process and the ssg-config

0.0.17

- Implement data import
- Pagination changes

0.0.16

- Additional cleanup

0.0.15

- Windows fixes

0.0.14

- Front matter is now read from layouts and views
- Removing opengraph and twitter meta data from build

0.0.13

- Removing debug code

0.0.12

- Now works on Windows

0.0.11

- Windows changes

0.0.10

- Much of the `build` command has been restructured to get pagination working.
- Simple pagination working now (pageSize of 1).
- Files are now output based on `prc.outFile` and not by directory structure and fileSlug
- If a template has the `pagination` flag it will be removed from `collections.all`. Only renedered templates are retained
- Code cleanup

0.0.9

- CSS ad JS files are now monitored by `ssg watch` command and will trigger a build when a change is detected
- Use `find` instead of `contains` when checking layout/view arrays to determine if the item exists

0.0.8

- `/_includes` directory will is automatically excluded

0.0.7

- Correcting `ssg init` behavior when scaffolding application. It should work properly on Windows now.

0.0.6

- Adding `ssg serve` command that writes out the required `.htaccess` and `server.json` to serve static content if not already present. Also starts a static web server to see your changes.
- Clean up commands formatting and comments

0.0.5

- Adding `view` attribute to specify how a template is rendered irregardless of type. If view is not spcified it will fall back to `type`
- ColdFusion templates will now honor `view` or `type` attributes when rendering
- Adding `ssg_state` variable that monitors folder structure and which layouts/includes exist
