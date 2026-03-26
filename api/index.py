from urllib.parse import parse_qsl, urlencode, urlparse

from app import AppHandler, initialize_database


initialize_database()


class handler(AppHandler):
    def _restore_original_path(self) -> None:
        parsed_url = urlparse(self.path)
        original_path = ""
        kept_query_pairs: list[tuple[str, str]] = []

        for key, value in parse_qsl(parsed_url.query, keep_blank_values=True):
            if key == "_route" and not original_path:
                original_path = "/" + value.lstrip("/")
                continue
            kept_query_pairs.append((key, value))

        if not original_path:
            return

        next_query = urlencode(kept_query_pairs, doseq=True)
        self.path = original_path + (f"?{next_query}" if next_query else "")

    def do_GET(self) -> None:
        self._restore_original_path()
        super().do_GET()

    def do_POST(self) -> None:
        self._restore_original_path()
        super().do_POST()
