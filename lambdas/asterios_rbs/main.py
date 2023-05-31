from typing import Optional

from lxml import etree
import logging

import boto3
import requests


logging.getLogger().setLevel("INFO")
logging.getLogger().addHandler(logging.StreamHandler())

# Server indexes: 0 - x5, 8 - x7
SERVER_INDEXES = [0]


BUCKET_NAME = "asterios-rbs"
RSS_URL = "https://asterios.tm/index.php?cmd=rss&serv={server_index}&count=10&out=xml"


def write_object_to_s3(boss_name: str, content: str):
    s3 = boto3.resource("s3")
    s3_object = s3.Object(BUCKET_NAME, f"{boss_name}")
    s3_object.put(Body=content)


def parse_last_killed_boss(rss_url: str) -> dict[str, Optional[str]]:
    """
    Find time for the last killed boss. It's not a guarantee it was killed a few mins ago.
    We just need the time of last kill.

    :param rss_url: url for RSS feed with list of killed bosses.
    :return: dictionary with the time when the requested boss was killed the last time. Format is: 29 May 2023 11:02:51 +0300
    """
    last_killed_mapping = {
        "cabrio": None,
        "hallate": None,
        "kernon": None,
        "golkonda": None
    }
    # Get response from RSS feed.
    response = requests.get(rss_url)

    # Parse XML into Python structure.
    # Create UTF-8 parsed to avoid issues with unicode.
    parser = etree.XMLParser(ns_clean=True, recover=True, encoding="utf-8")
    tree = etree.fromstring(response.text.encode("utf-8"), parser=parser)
    for element in tree.xpath(".//item"):
        # Get required fields from xml structure.
        title = element.find("title").text
        pub_date = element.find("pubDate").text
        for boss_name in last_killed_mapping.keys():
            if boss_name in title.lower() and last_killed_mapping.get(boss_name) is None:
                last_killed_mapping[boss_name] = pub_date
                write_object_to_s3(boss_name, pub_date)
    return last_killed_mapping


def invoke(event, _):
    logging.info("Testing message goes here!.")
    for server_index in SERVER_INDEXES:
        rss_url = RSS_URL.format(server_index=server_index)
        latest_updates = parse_last_killed_boss(rss_url)
        logging.info(f"Latest updates => {latest_updates}")

