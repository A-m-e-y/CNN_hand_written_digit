`timescale 1ns/1ps

// Simple testbench for MatrixMul AXI Wrapper
// Tests basic AXI write/read transactions and matrix multiplication

module tb_matrixmul_axi_wrapper();

    // Parameters
    parameter MAX_M = 4;
    parameter MAX_K = 4;
    parameter MAX_N = 4;
    parameter C_S00_AXI_DATA_WIDTH = 32;
    parameter C_S00_AXI_ADDR_WIDTH = 8;
    parameter CLK_PERIOD = 10; // 100MHz clock

    // Clock and reset
    reg s00_axi_aclk;
    reg s00_axi_aresetn;
    
    // AXI4-Lite signals
    reg [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_awaddr;
    reg [2:0] s00_axi_awprot;
    reg s00_axi_awvalid;
    wire s00_axi_awready;
    reg [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_wdata;
    reg [(C_S00_AXI_DATA_WIDTH/8)-1:0] s00_axi_wstrb;
    reg s00_axi_wvalid;
    wire s00_axi_wready;
    wire [1:0] s00_axi_bresp;
    wire s00_axi_bvalid;
    reg s00_axi_bready;
    reg [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_araddr;
    reg [2:0] s00_axi_arprot;
    reg s00_axi_arvalid;
    wire s00_axi_arready;
    wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_rdata;
    wire [1:0] s00_axi_rresp;
    wire s00_axi_rvalid;
    reg s00_axi_rready;

    // Instantiate DUT
    matrixmul_axi_wrapper #(
        .MAX_M(MAX_M),
        .MAX_K(MAX_K),
        .MAX_N(MAX_N),
        .C_S00_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
        .C_S00_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
    ) dut (
        .s00_axi_aclk(s00_axi_aclk),
        .s00_axi_aresetn(s00_axi_aresetn),
        .s00_axi_awaddr(s00_axi_awaddr),
        .s00_axi_awprot(s00_axi_awprot),
        .s00_axi_awvalid(s00_axi_awvalid),
        .s00_axi_awready(s00_axi_awready),
        .s00_axi_wdata(s00_axi_wdata),
        .s00_axi_wstrb(s00_axi_wstrb),
        .s00_axi_wvalid(s00_axi_wvalid),
        .s00_axi_wready(s00_axi_wready),
        .s00_axi_bresp(s00_axi_bresp),
        .s00_axi_bvalid(s00_axi_bvalid),
        .s00_axi_bready(s00_axi_bready),
        .s00_axi_araddr(s00_axi_araddr),
        .s00_axi_arprot(s00_axi_arprot),
        .s00_axi_arvalid(s00_axi_arvalid),
        .s00_axi_arready(s00_axi_arready),
        .s00_axi_rdata(s00_axi_rdata),
        .s00_axi_rresp(s00_axi_rresp),
        .s00_axi_rvalid(s00_axi_rvalid),
        .s00_axi_rready(s00_axi_rready)
    );

    // Clock generation
    initial begin
        s00_axi_aclk = 0;
        forever #(CLK_PERIOD/2) s00_axi_aclk = ~s00_axi_aclk;
    end

    // Test matrices (4x4)
    // A = Identity matrix, B = [1,2,3,4; 5,6,7,8; 9,10,11,12; 13,14,15,16]
    // Expected C = B (since A is identity)
    reg [31:0] matrix_A [0:15];
    reg [31:0] matrix_B [0:15];
    reg [31:0] matrix_C_expected [0:15];
    reg [31:0] matrix_C_actual [0:15];
    
    integer i;
    
    // Initialize test matrices
    initial begin
        // Matrix A: Identity
        for (i = 0; i < 16; i = i + 1) begin
            if (i % 5 == 0)  // Diagonal elements
                matrix_A[i] = 32'h3F800000; // 1.0 in IEEE 754
            else
                matrix_A[i] = 32'h00000000; // 0.0
        end
        
        // Matrix B: Sequential values
        matrix_B[0]  = 32'h3F800000; // 1.0
        matrix_B[1]  = 32'h40000000; // 2.0
        matrix_B[2]  = 32'h40400000; // 3.0
        matrix_B[3]  = 32'h40800000; // 4.0
        matrix_B[4]  = 32'h40A00000; // 5.0
        matrix_B[5]  = 32'h40C00000; // 6.0
        matrix_B[6]  = 32'h40E00000; // 7.0
        matrix_B[7]  = 32'h41000000; // 8.0
        matrix_B[8]  = 32'h41100000; // 9.0
        matrix_B[9]  = 32'h41200000; // 10.0
        matrix_B[10] = 32'h41300000; // 11.0
        matrix_B[11] = 32'h41400000; // 12.0
        matrix_B[12] = 32'h41500000; // 13.0
        matrix_B[13] = 32'h41600000; // 14.0
        matrix_B[14] = 32'h41700000; // 15.0
        matrix_B[15] = 32'h41800000; // 16.0
        
        // Expected result: C = A * B = I * B = B
        for (i = 0; i < 16; i = i + 1) begin
            matrix_C_expected[i] = matrix_B[i];
        end
    end

    // AXI Write Task
    task axi_write;
        input [C_S00_AXI_ADDR_WIDTH-1:0] addr;
        input [C_S00_AXI_DATA_WIDTH-1:0] data;
        integer timeout_count;
        begin
            $display("Time: %0t - AXI Write: addr=0x%02h, data=0x%08h", $time, addr, data);
            @(posedge s00_axi_aclk);
            s00_axi_awaddr = addr;
            s00_axi_awvalid = 1;
            s00_axi_awprot = 0;
            s00_axi_wdata = data;
            s00_axi_wvalid = 1;
            s00_axi_wstrb = 4'hF;
            s00_axi_bready = 1;
            
            // Wait for write response (keep valid signals high until bvalid)
            timeout_count = 0;
            @(posedge s00_axi_aclk);
            while (!s00_axi_bvalid) begin
                @(posedge s00_axi_aclk);
                timeout_count = timeout_count + 1;
                if (timeout_count > 100) begin
                    $display("ERROR: AXI write timeout waiting for bvalid!");
                    $display("  awready=%b, wready=%b, bvalid=%b", s00_axi_awready, s00_axi_wready, s00_axi_bvalid);
                    $finish;
                end
            end
            $display("Time: %0t - Write response received (bvalid=%b)", $time, s00_axi_bvalid);
            
            // Now de-assert valid and ready signals
            s00_axi_awvalid = 0;
            s00_axi_wvalid = 0;
            s00_axi_bready = 0;
            @(posedge s00_axi_aclk);
        end
    endtask

    // AXI Read Task
    task axi_read;
        input [C_S00_AXI_ADDR_WIDTH-1:0] addr;
        output [C_S00_AXI_DATA_WIDTH-1:0] data;
        integer timeout_count;
        begin
            @(posedge s00_axi_aclk);
            s00_axi_araddr = addr;
            s00_axi_arvalid = 1;
            s00_axi_arprot = 0;
            s00_axi_rready = 1;
            
            // Wait for read data to be valid
            timeout_count = 0;
            @(posedge s00_axi_aclk);
            while (!s00_axi_rvalid) begin
                @(posedge s00_axi_aclk);
                timeout_count = timeout_count + 1;
                if (timeout_count > 100) begin
                    $display("ERROR: AXI read timeout waiting for rvalid!");
                    $display("  arready=%b, rvalid=%b", s00_axi_arready, s00_axi_rvalid);
                    $finish;
                end
            end
            data = s00_axi_rdata;
            
            // De-assert signals
            s00_axi_arvalid = 0;
            s00_axi_rready = 0;
            @(posedge s00_axi_aclk);
        end
    endtask

    // Test sequence
    reg [31:0] read_data;
    reg [31:0] status;
    integer errors;
    
    initial begin
        $display("TB STARTED - Time: %0t", $time);
        // Initialize signals
        s00_axi_aresetn = 0;
        s00_axi_awaddr = 0;
        s00_axi_awprot = 0;
        s00_axi_awvalid = 0;
        s00_axi_wdata = 0;
        s00_axi_wstrb = 0;
        s00_axi_wvalid = 0;
        s00_axi_bready = 0;
        s00_axi_araddr = 0;
        s00_axi_arprot = 0;
        s00_axi_arvalid = 0;
        s00_axi_rready = 0;
        errors = 0;
        
        // Reset
        #(CLK_PERIOD*10);
        s00_axi_aresetn = 1;
        #(CLK_PERIOD*5);
        
        $display("=== MatrixMul AXI Wrapper Testbench ===");
        $display("Time: %0t - Starting test...", $time);
        
        // 1. Set dimensions (M=4, K=4, N=4)
        $display("Time: %0t - Setting dimensions M=4, K=4, N=4", $time);
        axi_write(8'h08, 32'd4); // M dimension
        axi_write(8'h0C, 32'd4); // K dimension
        axi_write(8'h10, 32'd4); // N dimension
        
        // Read back dimensions to verify
        axi_read(8'h08, read_data);
        $display("Time: %0t - Read back M dimension: %0d", $time, read_data);
        axi_read(8'h0C, read_data);
        $display("Time: %0t - Read back K dimension: %0d", $time, read_data);
        axi_read(8'h10, read_data);
        $display("Time: %0t - Read back N dimension: %0d", $time, read_data);
        
        // 2. Load Matrix A (select mem A)
        $display("Time: %0t - Loading Matrix A", $time);
        axi_write(8'h00, 32'h00000000); // Control: select Matrix A
        for (i = 0; i < 16; i = i + 1) begin
            axi_write(8'h14, i); // Address
            axi_write(8'h18, matrix_A[i]); // Data
        end
        
        // Verify Matrix A was written correctly (read back element 0)
        axi_write(8'h14, 0); // Address 0
        #(CLK_PERIOD*5); // Wait for BRAM
        axi_read(8'h1C, read_data); // Read data
        $display("Time: %0t - Matrix A[0] readback: 0x%08h (expected 0x%08h)", $time, read_data, matrix_A[0]);
        
        // 3. Load Matrix B (select mem B)
        $display("Time: %0t - Loading Matrix B", $time);
        axi_write(8'h00, 32'h00000004); // Control: select Matrix B
        for (i = 0; i < 16; i = i + 1) begin
            axi_write(8'h14, i); // Address
            axi_write(8'h18, matrix_B[i]); // Data
        end
        
        // 4. Start computation
        $display("Time: %0t - Starting computation", $time);
        axi_read(8'h04, status);
        $display("Time: %0t - Status BEFORE start: 0x%08h (done=%b, busy=%b)", $time, status, status[1], status[2]);
        axi_write(8'h00, 32'h00000001); // Control: START bit
        axi_read(8'h04, status);
        $display("Time: %0t - Status AFTER start: 0x%08h (done=%b, busy=%b)", $time, status, status[1], status[2]);
        
        // 5. Poll for completion
        $display("Time: %0t - Waiting for completion...", $time);
        status = 0;
        while (status[1] == 0) begin  // Check engine_done bit (bit 1)
            axi_read(8'h04, status); // Read status register
            $display("Time: %0t - Status: 0x%08h (done=%b, busy=%b)", $time, status, status[1], status[2]);
            #(CLK_PERIOD*10);
        end
        $display("Time: %0t - Computation done!", $time);
        
        // 6. Read result Matrix C
        $display("Time: %0t - Reading result Matrix C", $time);
        axi_write(8'h00, 32'h00000008); // Control: select Matrix C
        for (i = 0; i < 16; i = i + 1) begin
            axi_write(8'h14, i); // Address
            #(CLK_PERIOD*2); // Wait for BRAM read latency
            axi_read(8'h1C, read_data); // Read data
            matrix_C_actual[i] = read_data;
            
            // Compare with expected
            if (read_data !== matrix_C_expected[i]) begin
                $display("ERROR at index %0d: Expected %h, Got %h", i, matrix_C_expected[i], read_data);
                errors = errors + 1;
            end
        end
        
        // 7. Display results
        $display("\n=== Test Results ===");
        $display("Matrix C (Result):");
        for (i = 0; i < 4; i = i + 1) begin
            $display("  %h %h %h %h", 
                matrix_C_actual[i*4+0], matrix_C_actual[i*4+1],
                matrix_C_actual[i*4+2], matrix_C_actual[i*4+3]);
        end
        
        if (errors == 0) begin
            $display("\n*** TEST PASSED ***");
        end else begin
            $display("\n*** TEST FAILED with %0d errors ***", errors);
        end
        
        #(CLK_PERIOD*100);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD*500000);  // Longer timeout to see if computation ever completes
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
