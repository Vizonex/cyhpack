"""Used for providing support for hpack functionality and also h2 support."""

try:
    from hpack.exceptions import HPACKError, HPACKDecodingError
except ModuleNotFoundError:

    class HPACKError(Exception):
        """
        The base class for all ``hpack`` exceptions.
        """

    class HPACKDecodingError(HPACKError):
        """
        An error has been encountered while performing HPACK decoding.
        """


__all__ = ("HPACKDecodingError", "HPACKError")
