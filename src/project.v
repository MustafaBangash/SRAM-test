// SPDX-FileCopyrightText: © 2024 Mustafa Bangash
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

// =============================================================================
// Simple 4-Bit SRAM Test Circuit
// =============================================================================
// Single row, single column = 4 bits for testing analog memory integration
//
// Pin Mapping:
//   Inputs  [7:0]: [7:6]=unused, [5]=enable, [4]=read_not_write, [3:0]=data_in
//   Outputs [7:0]: [7:5]=unused, [4]=ready, [3:0]=data_out
//
// Operation:
//   - Write: enable=1, read_not_write=0, data_in=4'bXXXX → writes to memory
//   - Read:  enable=1, read_not_write=1 → reads from memory to data_out
//   - Takes 2 clock cycles, ready=1 when done
//

module tt_um_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // =========================================================================
    // Pin assignments
    // =========================================================================
    wire [3:0] data_in = ui_in[3:0];
    wire read_not_write = ui_in[4];
    wire enable = ui_in[5];
    
    wire [3:0] data_out;
    wire ready;
    
    assign uo_out = {3'b0, ready, data_out};
    
    // Unused bidirectional pins
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
    
    // =========================================================================
    // FSM States
    // =========================================================================
    localparam IDLE   = 2'b00;
    localparam CYCLE1 = 2'b01;
    
    reg [1:0] state, next_state;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (enable)
                    next_state = CYCLE1;
                else
                    next_state = IDLE;
            end
            
            CYCLE1: begin
                next_state = IDLE;  // Single cycle operation
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // =========================================================================
    // Control signals
    // =========================================================================
    wire wordline = (state == CYCLE1);
    wire write_enable = (state == CYCLE1) && !read_not_write;
    wire read_enable = (state == CYCLE1) && read_not_write;
    
    assign ready = (state == IDLE);
    
    // =========================================================================
    // Bitline drivers (for write operations)
    // =========================================================================
    // Tri-state drivers: drive bitlines during write, hi-Z during read
    wire [3:0] bitline;
    wire [3:0] bitline_bar;
    
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : write_drivers
            // 2-stage buffer for drive strength
            wire bit_buffered, bit_bar_buffered;
            assign bit_buffered = data_in[i];
            assign bit_bar_buffered = ~data_in[i];
            
            // Tri-state: drive when writing, hi-Z when reading
            assign bitline[i] = write_enable ? bit_buffered : 1'bz;
            assign bitline_bar[i] = write_enable ? bit_bar_buffered : 1'bz;
        end
    endgenerate
    
    // =========================================================================
    // Memory cell interface (4 bits)
    // =========================================================================
    // This is where the analog 6T SRAM cells connect in Magic layout
    //
    // For digital simulation, we use a behavioral model:
    
    `ifndef SYNTHESIS
        // =======================================================================
        // SIMULATION: Functional memory model
        // =======================================================================
        reg [3:0] memory_cell;
        
        initial begin
            memory_cell = 4'b0;
        end
        
        // Write: when wordline high and bitlines driven
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                memory_cell <= 4'b0;
            end else if (wordline && write_enable) begin
                memory_cell <= data_in;
            end
        end
        
        // Read: sense the memory cell value
        wire [3:0] sense_data = memory_cell;
        
    `else
        // =======================================================================
        // SYNTHESIS: UNIQUE PLACEHOLDER CELLS (DELETE THESE IN MAGIC!)
        // =======================================================================
        // Using DECAP_8 cells as unique, easy-to-find placeholders for the
        // 6T SRAM cells you'll add manually in Magic layout.
        //
        // WHY DECAP_8?
        // - Unique size that synthesizer won't add elsewhere
        // - Easy to find: select cell *decap_8* in Magic
        // - Exactly 8 instances (4 bits × 2 per bit)
        // - Small footprint
        //
        // Integration steps:
        // 1. Generate GDS - you'll see exactly 8× decap_8 cells
        // 2. In Magic: select cell *decap_8*
        // 3. DELETE all 8 instances
        // 4. Place 4× 6T SRAM cells in that space
        // 5. Connect: WL, BL[i], BLB[i] to each cell
        // 6. Add precharge and sense amps
        
        genvar j;
        generate
            for (j = 0; j < 4; j = j + 1) begin : SRAM_CELL_PLACEHOLDER
                // BL path placeholder
                (* keep = "true" *)
                sky130_fd_sc_hd__decap_8 BL_MARKER ();
                
                // BLB path placeholder  
                (* keep = "true" *)
                sky130_fd_sc_hd__decap_8 BLB_MARKER ();
            end
        endgenerate
        
        // Dummy connections to prevent optimization
        wire [3:0] sense_data = {4{wordline & |bitline & |bitline_bar}};
        
    `endif
    
    // =========================================================================
    // Sense amplifier / Read path
    // =========================================================================
    reg [3:0] read_data;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_data <= 4'b0;
        end else if (read_enable) begin
            read_data <= sense_data;
        end
    end
    
    assign data_out = read_data;
    
    // =========================================================================
    // Unused signals
    // =========================================================================
    wire _unused = &{ena, uio_in, 1'b0};

endmodule

`default_nettype wire
