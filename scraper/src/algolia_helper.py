"""AlgoliaHelper
Wrapper on top of the AlgoliaSearch API client"""

from algoliasearch.search_client import SearchClient

from builtins import range

from os import environ
import urllib.parse
import re
import json


class AlgoliaHelper:
    """AlgoliaHelper"""

    def __init__(self, app_id, api_key, index_name, index_name_tmp, settings, query_rules):
        self.algolia_client = SearchClient.create(app_id, api_key)
        self.index_name = index_name
        self.index_name_tmp = index_name_tmp
        self.algolia_index = self.algolia_client.init_index(self.index_name)
        self.algolia_index_tmp = self.algolia_client.init_index(
            self.index_name_tmp)
        self.algolia_client.copy_rules(
            self.index_name,
            self.index_name_tmp
        )
        self.algolia_index_tmp.set_settings(settings)

        if len(query_rules) > 0:
            self.algolia_index_tmp.save_rules(query_rules, True, True)

    @property
    def pagerank_rules(self):
        if hasattr(self, "_pagerank_rules"):
            return self._pagerank_rules

        pagerank_rules = environ.get("SCRAPER_PAGERANK_RULES")
        if pagerank_rules:
            rules = []
            pagerank_rules = json.loads(pagerank_rules)
            for rule in pagerank_rules:
                if "field" not in rule or "pattern" not in rule or "page_rank" not in rule:
                    logger.warning(f"Invalid pagerank rule: {rule}")
                    continue

                try:
                    rule["pattern"] = re.compile(rule["pattern"])
                except re.error:
                    logger.warning(f"Invalid regex pattern: {rule['pattern']}")
                    continue

                rules.append(rule)

            pagerank_rules = rules

        self._pagerank_rules = pagerank_rules or []
        return self._pagerank_rules

    @property
    def attributes_to_remove(self):
        if hasattr(self, "_attributes_to_remove"):
            return self._attributes_to_remove

        self._attributes_to_remove = []

        attributes_to_remove = environ.get("SCRAPER_REMOVE_ATTRIBUTES")
        if attributes_to_remove:
            attr_rm = json.loads(attributes_to_remove)
            if not isinstance(attr_rm, list):
                logger.warning("Invalid format for SCRAPER_REMOVE_ATTRIBUTES")
                return self._attributes_to_remove

            for attr in attr_rm:
                try:
                    self._attributes_to_remove.append(re.compile(attr))
                except re.error:
                    logger.warning(f"Invalid regex pattern: {attr}")
                    continue

        return self._attributes_to_remove

    def remove_unwanted_attributes(self, record):
        for attr in self.attributes_to_remove:
            for key in list(record.keys()):
                if attr.search(key):
                    del record[key]

        return record

    @property
    def restore_host_func(self):
        if not hasattr(self, "_restore_host_func"):
            override_host = environ.get("OVERRIDE_HOST")
            override_url = f"https://{override_host}"
            localserver_host = environ.get("LOCALSERVER_HOST")
            localserver_url = environ.get("LOCALSERVER_URL")

            if not override_host or not localserver_host or not localserver_url:
                self._restore_host_func = None
            else:
                def func(url):
                    url = url.replace(localserver_url, override_url)
                    url = url.replace(localserver_host, override_host)
                    return url

                self._restore_host_func = func

        return self._restore_host_func

    def restore_host(self, url):
        if self.restore_host_func:
            return self.restore_host_func(url)

        return url

    @property
    def max_bytes_per_record(self):
        if not hasattr(self, "_max_bytes_per_record"):
            self._max_bytes_per_record = int(environ.get("SCRAPER_MAX_RECORD_BYTES", 0))
            if self._max_bytes_per_record <= 0:
                self._max_bytes_per_record = None

        return self._max_bytes_per_record

    def post_processing(self, url, records):
        url = self.restore_host(url)

        for record in records:
            if self.restore_host_func:
                # Reset the overriden host
                for var in ["url", "url_without_anchor", "url_without_variables"]:
                    if var in record:
                        record[var] = self.restore_host(record[var])

            # Parse the URL to return the path
            if "url_without_anchor" in record:
                record["path"] = urllib.parse.urlparse(record["url_without_anchor"]).path

            for rule in self.pagerank_rules:
                if rule["field"] in record and rule["pattern"].search(record[rule["field"]]):
                    record["weight"]["page_rank"] = record["weight"].get("page_rank", 0) + rule["page_rank"]

            record = self.remove_unwanted_attributes(record)

        return (url, records)

    def _save_records(self, records, step):
        for i in range(0, len(records), step):
            records_to_dump = records[i:i + step]

            if environ.get("SHOW_RECORDS") == "1":
                print(json.dumps(records_to_dump, indent=2, sort_keys=True, separators=(',', ': ')))

            self.algolia_index_tmp.save_objects(records_to_dump)

    def add_records(self, records, url, from_sitemap):
        """Add new records to the temporary index"""
        record_count = len(records)

        # Added for post-processing
        url, records = self.post_processing(url, records)

        # Filter the records to get two lists: the records fitting the
        # expected size, and the records that are too big
        records_ok = []
        records_too_big = []
        if self.max_bytes_per_record is None:
            records_ok = records
        else:
            max_size = self.max_bytes_per_record
            for record in records:
                record_size = len(json.dumps(record, separators=(',', ':')).encode('utf-8'))
                if record_size > max_size:
                    print(f"Record objectID={record['objectID']} is too big ({record_size}/{max_size} bytes), page={url}")
                    records_too_big.append(record)
                else:
                    records_ok.append(record)

        # Send the recprds that are ok to the index separately, so we
        # avoid a single too big record to block the whole batch
        self._save_records(records_ok, 50)

        # TODO: figure out how to split those records so they can be saved
        #       instead of being discarded
        #  self._save_records(records_too_big, 10)

        color = "96" if from_sitemap else "94"

        print(
            '\033[{}m> DocSearch: \033[0m{}\033[93m {} records\033[0m)'.format(
                color, url, record_count))

    def add_synonyms(self, synonyms):
        synonyms_list = []
        for _, value in list(synonyms.items()):
            synonyms_list.append(value)

        self.algolia_index_tmp.save_synonyms(synonyms_list)
        print(
            '\033[94m> DocSearch: \033[0m Synonyms (\033[93m{} synonyms\033[0m)'.format(
                len(synonyms_list)))

    def commit_tmp_index(self):
        """Overwrite the real index with the temporary one"""
        # print("Update settings")
        self.algolia_client.move_index(self.index_name_tmp, self.index_name)
