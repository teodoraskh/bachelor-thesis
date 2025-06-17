package params_pkg;

    // --------------------------------------------------------------------------
    // Type definitions
    // --------------------------------------------------------------------------
    // Fixed value
    parameter integer LENGTH                      = 64;

    // Can be changed depending on the scheme
    // Dilithium is default
    parameter integer           MODULUS_LENGTH    = 23;
    parameter logic[LENGTH-1:0] MODULUS           = 8380417; //
    parameter logic[LENGTH-1:0] MOD_INV           = -8193;   // -(2^13 + 1)
    parameter logic[LENGTH-1:0] MU                = 8396807;

    // Kyber
    // parameter integer           MODULUS_LENGTH    = 12;
    // parameter logic[LENGTH-1:0] MODULUS           = 3329;
    // parameter logic[LENGTH-1:0] MOD_INV           = -769;  // -(2^9+2^8+1)
    // parameter logic[LENGTH-1:0] MU                = 5039;

endpackage