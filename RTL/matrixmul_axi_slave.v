`timescale 1ns/1ps

module matrixmul_axi_slave #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 8,
    parameter MAX_M = 16,
    parameter MAX_K = 16,
    parameter MAX_N = 16,
    parameter ADDR_M_BITS = $clog2(MAX_M),
    parameter ADDR_K_BITS = $clog2(MAX_K),
    parameter ADDR_N_BITS = $clog2(MAX_N),
    parameter MAX_ADDR_A = MAX_M * MAX_K,
    parameter MAX_ADDR_B = MAX_K * MAX_N,
    parameter MAX_ADDR_C = MAX_M * MAX_N,
    parameter ADDR_A_BITS = $clog2(MAX_ADDR_A),
    parameter ADDR_B_BITS = $clog2(MAX_ADDR_B),
    parameter ADDR_C_BITS = $clog2(MAX_ADDR_C)
)(
    // Global Clock Signal
    input wire S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input wire S_AXI_ARESETN,
    
    // Write address (issued by master, accepted by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    // Write channel Protection type
    input wire [2:0] S_AXI_AWPROT,
    // Write address valid
    input wire S_AXI_AWVALID,
    // Write address ready
    output wire S_AXI_AWREADY,
    
    // Write data (issued by master, accepted by Slave) 
    input wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    // Write strobes
    input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    // Write valid
    input wire S_AXI_WVALID,
    // Write ready
    output wire S_AXI_WREADY,
    
    // Write response
    output wire [1:0] S_AXI_BRESP,
    // Write response valid
    output wire S_AXI_BVALID,
    // Response ready
    input wire S_AXI_BREADY,
    
    // Read address (issued by master, accepted by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    // Protection type
    input wire [2:0] S_AXI_ARPROT,
    // Read address valid
    input wire S_AXI_ARVALID,
    // Read address ready
    output wire S_AXI_ARREADY,
    
    // Read data (issued by slave)
    output wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    // Read response
    output wire [1:0] S_AXI_RRESP,
    // Read valid
    output wire S_AXI_RVALID,
    // Read ready
    input wire S_AXI_RREADY,
    
    // User signals
    output reg engine_start,
    input wire engine_done,
    input wire engine_busy,
    output reg [ADDR_M_BITS:0] M_val,
    output reg [ADDR_K_BITS:0] K_val,
    output reg [ADDR_N_BITS:0] N_val,
    
    // Memory interface - Matrix A
    output reg mem_a_we,
    output reg [ADDR_A_BITS-1:0] mem_a_addr,
    output reg [31:0] mem_a_wdata,
    input wire [31:0] mem_a_rdata,
    
    // Memory interface - Matrix B
    output reg mem_b_we,
    output reg [ADDR_B_BITS-1:0] mem_b_addr,
    output reg [31:0] mem_b_wdata,
    input wire [31:0] mem_b_rdata,
    
    // Memory interface - Matrix C
    output reg mem_c_we,
    output reg [ADDR_C_BITS-1:0] mem_c_addr,
    output reg [31:0] mem_c_wdata,
    input wire [31:0] mem_c_rdata
);

    // AXI4LITE signals
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp;
    reg axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    reg axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0] axi_rresp;
    reg axi_rvalid;

    // Example-specific design signals
    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = 5;
    
    //----------------------------------------------
    // Register Map
    //----------------------------------------------
    // 0x00: Control Register
    // 0x04: Status Register  
    // 0x08: M Dimension
    // 0x0C: K Dimension
    // 0x10: N Dimension
    // 0x14: Memory Address Register
    // 0x18: Memory Write Data Register
    // 0x1C: Memory Read Data Register
    
    reg [C_S_AXI_DATA_WIDTH-1:0] control_reg;
    wire [C_S_AXI_DATA_WIDTH-1:0] status_reg;
    reg [C_S_AXI_DATA_WIDTH-1:0] m_dim_reg;
    reg [C_S_AXI_DATA_WIDTH-1:0] k_dim_reg;
    reg [C_S_AXI_DATA_WIDTH-1:0] n_dim_reg;
    reg [C_S_AXI_DATA_WIDTH-1:0] mem_addr_reg;
    reg [C_S_AXI_DATA_WIDTH-1:0] mem_wdata_reg;
    reg [C_S_AXI_DATA_WIDTH-1:0] mem_rdata_reg;
    
    wire slv_reg_rden;
    wire slv_reg_wren;
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;
    integer byte_index;
    reg aw_en;

    // Control register bits
    wire start_bit = control_reg[0];
    wire reset_bit = control_reg[1];
    wire [1:0] mem_sel = control_reg[3:2];  // 0=A, 1=B, 2=C
    
    // Status register bits
    assign status_reg = {29'b0, engine_busy, engine_done, 1'b0};
    
    // I/O Connections assignments
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY = axi_wready;
    assign S_AXI_BRESP = axi_bresp;
    assign S_AXI_BVALID = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA = axi_rdata;
    assign S_AXI_RRESP = axi_rresp;
    assign S_AXI_RVALID = axi_rvalid;
    
    // Implement axi_awready generation
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            axi_awready <= 1'b0;
            aw_en <= 1'b1;
        end else begin    
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                axi_awready <= 1'b1;
                aw_en <= 1'b0;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                aw_en <= 1'b1;
                axi_awready <= 1'b0;
            end else begin
                axi_awready <= 1'b0;
            end
        end 
    end       

    // Implement axi_awaddr latching
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            axi_awaddr <= 0;
        end else begin    
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                axi_awaddr <= S_AXI_AWADDR;
            end
        end 
    end       

    // Implement axi_wready generation
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            axi_wready <= 1'b0;
        end else begin    
            if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end 
    end       

    // Implement memory mapped register select and write logic generation
    assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            control_reg <= 0;
            m_dim_reg <= 0;
            k_dim_reg <= 0;
            n_dim_reg <= 0;
            mem_addr_reg <= 0;
            mem_wdata_reg <= 0;
        end else begin
            // Auto-clear start bit after one cycle
            if (control_reg[0] == 1'b1) begin
                control_reg[0] <= 1'b0;
            end
            
            if (slv_reg_wren) begin
                case (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
                    6'h00: begin // Control register
                        for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                            if (S_AXI_WSTRB[byte_index] == 1) begin
                                control_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            end  
                    end
                    6'h02: begin // M dimension
                        for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                            if (S_AXI_WSTRB[byte_index] == 1) begin
                                m_dim_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            end  
                    end
                    6'h03: begin // K dimension
                        for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                            if (S_AXI_WSTRB[byte_index] == 1) begin
                                k_dim_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            end  
                    end
                    6'h04: begin // N dimension
                        for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                            if (S_AXI_WSTRB[byte_index] == 1) begin
                                n_dim_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            end  
                    end
                    6'h05: begin // Memory address
                        for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                            if (S_AXI_WSTRB[byte_index] == 1) begin
                                mem_addr_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            end  
                    end
                    6'h06: begin // Memory write data
                        for (byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1)
                            if (S_AXI_WSTRB[byte_index] == 1) begin
                                mem_wdata_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            end  
                    end
                    default: begin
                        control_reg <= control_reg;
                        m_dim_reg <= m_dim_reg;
                        k_dim_reg <= k_dim_reg;
                        n_dim_reg <= n_dim_reg;
                        mem_addr_reg <= mem_addr_reg;
                        mem_wdata_reg <= mem_wdata_reg;
                    end
                endcase
            end
        end
    end    

    // Implement write response logic generation
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            axi_bvalid <= 0;
            axi_bresp <= 2'b0;
        end else begin    
            if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
                axi_bvalid <= 1'b1;
                axi_bresp <= 2'b0; // 'OKAY' response 
            end else begin
                if (S_AXI_BREADY && axi_bvalid) begin
                    axi_bvalid <= 1'b0; 
                end  
            end
        end
    end   

    // Implement axi_arready generation
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            axi_arready <= 1'b0;
            axi_araddr <= 32'b0;
        end else begin    
            if (~axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end
        end 
    end       

    // Implement axi_rvalid generation
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            axi_rvalid <= 0;
            axi_rresp <= 0;
        end else begin    
            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp <= 2'b0; // 'OKAY' response
            end else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end                
        end
    end    

    // Implement memory mapped register select and read logic generation
    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
    
    always @(*) begin
        // Address decoding for reading registers
        case (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
            6'h00: reg_data_out = control_reg;
            6'h01: reg_data_out = status_reg;
            6'h02: reg_data_out = m_dim_reg;
            6'h03: reg_data_out = k_dim_reg;
            6'h04: reg_data_out = n_dim_reg;
            6'h05: reg_data_out = mem_addr_reg;
            6'h06: reg_data_out = mem_wdata_reg;
            6'h07: reg_data_out = mem_rdata_reg;
            default: reg_data_out = 0;
        endcase
    end

    // Output register or memory read data
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            axi_rdata <= 0;
        end else begin    
            if (slv_reg_rden) begin
                axi_rdata <= reg_data_out;
            end   
        end
    end    

    //----------------------------------------------
    // User Logic
    //----------------------------------------------
    
    // Generate engine start pulse
    reg start_bit_d;
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            start_bit_d <= 1'b0;
            engine_start <= 1'b0;
        end else begin
            start_bit_d <= start_bit;
            engine_start <= start_bit & ~start_bit_d; // Rising edge detect
        end
    end
    
    // Update dimension outputs
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            M_val <= 0;
            K_val <= 0;
            N_val <= 0;
        end else begin
            M_val <= m_dim_reg[ADDR_M_BITS:0];
            K_val <= k_dim_reg[ADDR_K_BITS:0];
            N_val <= n_dim_reg[ADDR_N_BITS:0];
        end
    end
    
    // Memory interface logic
    reg mem_write_trigger, mem_write_trigger_d;
    reg mem_read_trigger, mem_read_trigger_d;
    
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            mem_write_trigger <= 1'b0;
            mem_write_trigger_d <= 1'b0;
            mem_read_trigger <= 1'b0;
            mem_read_trigger_d <= 1'b0;
        end else begin
            mem_write_trigger_d <= mem_write_trigger;
            mem_read_trigger_d <= mem_read_trigger;
            
            // Detect write to mem_wdata_reg (address 0x18) - triggers BRAM write
            if (slv_reg_wren && axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 6'h06) begin
                mem_write_trigger <= ~mem_write_trigger;
            end
            
            // Detect write to mem_addr_reg (address 0x14) - triggers BRAM read address update
            if (slv_reg_wren && axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 6'h05) begin
                mem_read_trigger <= ~mem_read_trigger;
            end
        end
    end
    
    wire mem_write_pulse = mem_write_trigger ^ mem_write_trigger_d;
    wire mem_read_pulse = mem_read_trigger ^ mem_read_trigger_d;
    
    // Memory write control
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            mem_a_we <= 1'b0;
            mem_b_we <= 1'b0;
            mem_c_we <= 1'b0;
            mem_a_addr <= 0;
            mem_b_addr <= 0;
            mem_c_addr <= 0;
            mem_a_wdata <= 0;
            mem_b_wdata <= 0;
            mem_c_wdata <= 0;
        end else begin
            // Default: disable writes
            mem_a_we <= 1'b0;
            mem_b_we <= 1'b0;
            mem_c_we <= 1'b0;
            
            // Update address when mem_addr_reg is written (for subsequent read or write)
            if (mem_read_pulse) begin
                case (mem_sel)
                    2'b00: mem_a_addr <= mem_addr_reg[ADDR_A_BITS-1:0];
                    2'b01: mem_b_addr <= mem_addr_reg[ADDR_B_BITS-1:0];
                    2'b10: mem_c_addr <= mem_addr_reg[ADDR_C_BITS-1:0];
                endcase
            end
            
            // Perform write when mem_wdata_reg is written
            if (mem_write_pulse) begin
                case (mem_sel)
                    2'b00: begin // Matrix A
                        mem_a_we <= 1'b1;
                        mem_a_wdata <= mem_wdata_reg;
                    end
                    2'b01: begin // Matrix B
                        mem_b_we <= 1'b1;
                        mem_b_wdata <= mem_wdata_reg;
                    end
                    2'b10: begin // Matrix C
                        mem_c_we <= 1'b1;
                        mem_c_wdata <= mem_wdata_reg;
                    end
                endcase
            end
        end
    end
    
    // Memory read data capture
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            mem_rdata_reg <= 0;
        end else begin
            // Capture read data (1 cycle delay for BRAM)
            // This continuously updates to reflect current BRAM output
            case (mem_sel)
                2'b00: mem_rdata_reg <= mem_a_rdata;
                2'b01: mem_rdata_reg <= mem_b_rdata;
                2'b10: mem_rdata_reg <= mem_c_rdata;
                default: mem_rdata_reg <= 0;
            endcase
        end
    end

endmodule
