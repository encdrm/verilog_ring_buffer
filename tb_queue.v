`timescale 1ns / 1ps

module tb_queue();

reg clk, rstn;
reg enqueue, dequeue;
reg [7:0] queue_in;
wire [7:0] queue_out;
wire full;
wire empty;

ring_buffer #(
    .WIDTH(8)
,   .LENGTH(5)
,   .OVERWRITABLE(0)
) Q1 (
    .clk(clk)
,   .rstn(rstn)
,   .enqueue_i(enqueue)
,   .dequeue_i(dequeue)
,   .data_i(queue_in)
,   .data_o(queue_out)
,   .full(full)
,   .empty(empty)
);

integer i;
initial begin
    clk = 0;
    rstn = 0;
    enqueue = 0; dequeue = 0;
    queue_in = 0;
    #20 rstn = 1;

    #20;
    for (i=0; i<16; i=i+1) begin
        enqueue = 1;
        queue_in = "a" + i;
        #10;
    end
    enqueue = 0;
    for (i=0; i<16; i=i+1) begin
        dequeue = 1;
        #10;
    end
    enqueue = 1;
    for (i=0; i<16; i=i+1) begin
        queue_in = "a" + i;
        #10;
    end
    #100;
    dequeue = 0;
    enqueue = 0;
    #100;
    $finish;
end

always #5 clk = ~clk;

endmodule
