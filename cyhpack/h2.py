"""
H2
--

This contains a backend class made for overriding h2.Connection
with our own `Encoder` and `Decoder` objects until h2 wants to support
our library that uses __ls-hpack__ under the hood.

There will likely need to be an Abstract class invented for h2 in the future
in order for cyhapck to be futher supported by h2.
"""

from __future__ import annotations

from h2.config import H2Configuration
from h2.connection import H2Connection as _H2Connection

from .hpack import Decoder, Encoder


class H2Connection(_H2Connection):
    """
    Contains an overridable version of H2Connection that drops
    python hpack in exchange for cyhpack for faster performance
    and speed.
    """

    def __init__(self, config: H2Configuration | None = None):
        super().__init__(config)
        self.encoder = Encoder()
        self.decoder = Decoder()

    
