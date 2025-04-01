package multipler_pkg;

    // --------------------------------------------------------------------------
    // Type definitions
    // --------------------------------------------------------------------------

    // Length definitions for the cipher
    parameter integer DATA_LENGTH       = 64;
    parameter integer BLOCK_LENGTH      = 16;
    parameter integer LENGTH            = 16;

    parameter integer NUM_BLOCKS        = DATA_LENGTH / BLOCK_LENGTH;
    parameter integer NUM_MULS          = NUM_BLOCKS * NUM_BLOCKS;

    typedef enum {
        idle, 
        compute,
        finish
    } state_t;

    typedef logic [LENGTH-1:0] counter_t;

endpackage