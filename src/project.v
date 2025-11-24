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
        // SYNTHESIS: Dummy placeholder cells (REPLACE THESE IN MAGIC!)
        // =======================================================================
        // These buffer chains reserve physical space and organize connections
        // for the 6T SRAM cells you'll add manually in Magic layout.
        //
        // Integration steps:
        // 1. Generate GDS - these will appear as buffer chains
        // 2. In Magic, identify and DELETE these dummy chains
        // 3. Place 6T SRAM cells in the same location
        // 4. Connect: WL, BL[i], BLB[i] to each cell
        // 5. Add precharge and sense amps
        
        wire [3:0] dummy_bl_load;
        wire [3:0] dummy_blb_load;
        
        genvar j;
        generate
            for (j = 0; j < 4; j = j + 1) begin : dummy_mem_cells
                // Buffer chain on BL side (simulates SRAM cell load)
                (* keep = "true" *)
                wire bl_in, bl_buf1, bl_buf2, bl_buf3;
                
                assign bl_in = bitline[j] & wordline;  // Input from write driver
                assign bl_buf1 = bl_in;
                assign bl_buf2 = bl_buf1;
                assign bl_buf3 = bl_buf2;
                assign dummy_bl_load[j] = bl_buf3;     // Output to sense path
                
                // Buffer chain on BLB side
                (* keep = "true" *)
                wire blb_in, blb_buf1, blb_buf2, blb_buf3;
                
                assign blb_in = bitline_bar[j] & wordline;
                assign blb_buf1 = blb_in;
                assign blb_buf2 = blb_buf1;
                assign blb_buf3 = blb_buf2;
                assign dummy_blb_load[j] = blb_buf3;
            end
        endgenerate
        
        // Combine dummy loads to create sense data
        // In real chip, this comes from sense amplifiers
        wire [3:0] sense_data = dummy_bl_load | dummy_blb_load;
        
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
