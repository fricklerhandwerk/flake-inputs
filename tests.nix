let
  lib = import ./lib.nix;
  # Test Unix timestamp for 2024-12-08 01:02:56
  timestamp = 1733619776;
in
{
  test-datetime-from-timestamp = {
    expr = map lib.datetime-from-timestamp [
      timestamp
      0
    ];
    expected = [
      {
        year = 2024;
        month = 12;
        day = 8;
        hour = 1;
        minute = 2;
        second = 56;
      }
      {
        year = 1970;
        month = 1;
        day = 1;
        hour = 0;
        minute = 0;
        second = 0;
      }
    ];
  };

  test-pad = {
    expr = [
      (lib.pad 2 "0" 5)
      (lib.pad 4 "0" 42)
      (lib.pad 3 " " 7)
    ];
    expected = [
      "05"
      "0042"
      "  7"
    ];
  };
}