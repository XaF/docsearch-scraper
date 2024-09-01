# DocSearch Scraper

This GitHub Action runs the [legacy run your own](https://docsearch.algolia.com/docs/legacy/run-your-own)
[DocSearch Scraper](https://github.com/algolia/docsearch-scraper) from a GitHub Actions runner, with the
capability to run the scraping locally.

This means that this scraper can actually work with private GitHub repositories, scraping the content of
a static website as built into a given build directory, instead of requiring a publicly-available webpage
to scrape.

## Usage

### Workflow

To use this action, add the following step to your GitHub Actions workflow:

```yaml
steps:
  - name: Run the DocSearch Scraper
    uses: XaF/docsearch-scraper@v0
    with:
      application_id: ${{ secrets.ALGOLIA_APPLICATION_ID }}
      write_api_key: ${{ secrets.ALGOLIA_WRITE_API_KEY }}
      override_host: the-real-hostname-of-the-website.com
```

### Inputs

| Parameter          | Description                                                                                             | Default      |
| ------------------ | ------------------------------------------------------------------------------------------------------- | ------------ |
| `application_id`   | The application ID provided by Algolia                                                                  | N/A          |
| `write_api_key`    | The *write* API key provided by Algolia                                                                 | N/A          |
| `config_file`      | The path, relative to the root of the directory, to the algolia configuration                           | `algolia.json` |
| `build_dir`      | The path, relative to the root of the directory, to the directory where the static website has been built | `build`        |
| `override_host` | When set, a local webserver will be used to serve the build directory, but the real hostname will be restored before pushing the results to the Algolia search index | N/A |

### Environment variables

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `SHOW_RECORDS` | If set to `1`, the records will be printed to the console as they are pushed to the Algolia index | `0` |

### Outputs

| Parameter | Description |
| --------- | ----------- |
| `pages_with_errors_count` | The number of pages where the scraper encountered an error |
| `pages_with_errors` | The list of pages where the scraper encountered an error |
| `pages_without_record_count` | The number of pages where the scraper did not find any record |
| `pages_without_record` | The list of pages where the scraper did not find any record |
| `too_big_records_count` | The number of records that were too big to be pushed to the Algolia index |
| `total_records` | The total number of records pushed to the Algolia index |

## Scraper

### Attributes

The scraper will send the following attributes to the Algolia index:

- `anchor` -- the anchor of the URL
- `content` -- the content of the page
- `content_camel`
- `docusaurus_tag` -- the tag of the Docusaurus page
- `hierarchy` -- the hierarchy of the page
- `hierarchy_camel`
- `hierarchy_radio`
- `hierarchy_radio_camel`
- `language` -- the language of the page
- `no_variables` -- whether the URL has no variables
- `objectID` -- the object ID
- `path` -- the path of the page (without the hostname)
- `tags` -- the tags of the page
- `type` -- the type of the record
- `url` -- the URL of the page
- `url_without_anchor` -- the URL of the page without the anchor nor variables
- `url_without_variables` -- the URL of the page without variables
- `version` -- the version of the page
- `weight` -- a nested object with values for:
  - `level` -- the level of the record in the hierarchy
  - `page_rank` -- the page rank of the record
  - `position` -- the position of the record (in the page?)

### Special configuration

The `algolia.json` configuration file can take special values that will only be used by the scraper:

#### `scraper_page_rank_rules`

This allows to apply modifier to the scraped records before pushing them to the index.
This takes a list of objects with the following properties:

- `field`: the name of the field to match
- `pattern`: a regular expression to match
- `page_rank`: the modifier to apply to the page rank (`10` will add 10 to the `page_rank`, while `-10` will remove 10)

```json
{
  "scraper": {
    "page_rank_rules": [
      {
        "field": "hierarchy.lvl0",
        "pattern": "API",
        "page_rank": 10
      },
      {
        "field": "path",
        "pattern": "^/deprecated/",
        "page_rank": -20
      }
    ]
  }
}
```

#### `scraper_remove_attributes`

This allows to remove some elements from the scraped records before pushing them to the index.
This can be useful when receiving errors such as "Record is too big" from Algolia, as you can
remove duplicate or unnecessary attributes for your use-case.

This takes a list of regular expression patterns to match the attribute names. Be mindful that
exact matching requires the `^` and `$` characters to be used.

```json
{
  "scraper": {
    "remove_attributes": [
      "^path$",
      "_camel$"
    ]
  }
}
```

This does not support nested attributes, and can only remove top-level attributes.

You should use this feature carefully as there is no protection against removing mandatory attributes.

#### `scraper_max_record_bytes`

This allows to set a maximum size for the records pushed to the Algolia index.
When a record is too big, it will be skipped and the `too_big_records_count` will be incremented. Skipping the record will allow for other records on that page to still be pushed to the index. If unset or set to the wrong value and a record is too big, the whole batch will be skipped.

By default, for free accounts, the maximum size is 10000 bytes, you could thus set this value to 10000 to avoid any record being too big.

```json
{
  "scraper": {
    "max_record_bytes": 10000
  }
}
```

## Useful links

- [Original scraper](https://github.com/algolia/docsearch-scraper), which is deprecated, but the original fork for this repository
  - [bitkill's fork](https://github.com/bitkill/docsearch-scraper), which I merged the changes of, as his fork was using more recent dependencies
- [Documentation](https://docsearch.algolia.com/)
- [Documentation source code](https://github.com/algolia/docsearch/tree/next/packages/website)
- [DocSearch UI](https://github.com/algolia/docsearch)
