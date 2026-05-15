from cyhpack import Encoder, Decoder
from hpack import Encoder as PyEncoder, Decoder as PyDecoder
import pytest


@pytest.fixture(
    params=(
        (
            [
                (":authority", "auth"),
                (
                    "user-agent",
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                ),
            ],
            b"A\x83\x1d\xa9\x9fz\xae\xd0\x7ff\xa2\x81\xb0\xda\xe0S\xfa\xe4j\xa4?\x84)\xa7z\x81\x02\xe0\xfbS\x91\xaaq\xaf\xb5<\xb8\xd7\xf6\xa45\xd7Ay\x16<\xc6K\r\xb2\xea\xec\xb9",
        ),
    )
)
def header_data(request: pytest.FixtureRequest) -> tuple[list[tuple[str, str]], bytes]:
    return request.param


class BaseTestEncoder:
    encoder: type[Encoder | PyEncoder]

    def test_encoding(self, header_data: tuple[list[tuple[str, str]], bytes]) -> None:
        enc = self.encoder()
        assert header_data[1] == enc.encode(header_data[0])


class BaseTestDecoder:
    decoder: type[Decoder | PyDecoder]

    def test_decoding(self, header_data: tuple[list[tuple[str, str]], bytes]) -> None:
        dec = self.decoder()
        assert header_data[0] == dec.decode(header_data[1])


class TestCEncoder(BaseTestEncoder):
    encoder = Encoder


class TestPyEncoder(BaseTestEncoder):
    encoder = PyEncoder


class TestCDecoder(BaseTestDecoder):
    decoder = Decoder


class TestPyDecoder(BaseTestDecoder):
    decoder = PyDecoder
