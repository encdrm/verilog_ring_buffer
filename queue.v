`timescale 1ns / 1ps
/**
 * This module implements a ring buffer with reconfigurable data width and size, overwrite mode support
 *
 * Parameters:
 *      WIDTH - 데이터 크기
 *      LENGTH - 최대 데이터 저장 개수
 *      OVERWRITABLE - Whether to allow overwrite when buffer is full
 *
 * Inputs:
 *      enqueue_i - Enqueue 신호
 *      dequeue_i - Dequeue 신호
 *      data_i - Enqueue 시 입력 데이터
 *
 * Outputs:
 *      data_o - Dequeue 시 출력 데이터
 *      full_o - Buffer 가득 찼는지 여부
 *      empty_o - Buffer 비었는지 여부
 * 
 * Ring buffer의 동작 상태를 작은 논리적인 단위로 나눠 계층화해 Combinational logic으로 기술하고, 
 * Sequential logic을 최대한 단순화하도록 짜면 어떨까 싶어 작성한 코드.
 * 이게 나을지, 전부 Sequential logic으로 짜는 게 나을지는 아직 모름.
 */
module ring_buffer #(
    parameter   WIDTH           = 8,
                LENGTH          = 1024,
                OVERWRITABLE    = 0  
)(
    clk
,   rstn
,   enqueue_i
,   dequeue_i
,   data_i
,   data_o
,   full
,   empty
);
input clk, rstn;
input enqueue_i;
input dequeue_i;
input       [WIDTH-1:0] data_i;
output reg  [WIDTH-1:0] data_o;
output reg              full;
output reg              empty;

localparam  MEM_DEPTH   = LENGTH + 1,           // LENGTH 개수 데이터 저장 위해선 LENGTH+1 Depth의 Memory 필요
            ADDR_BIT    = $clog2(MEM_DEPTH);    // Memory 주소 표현을 위한 비트 수

reg [WIDTH-1:0] buffer_m [0:MEM_DEPTH-1];
reg [ADDR_BIT-1:0] tail, head;

/**
 * 모듈의 상태를 판단하고, 다음 tail, head 값을 계산하는 logic
 * 
 * Variables:
 *      is_enq_deq_simult: Enqueue와 Dequeue 입력이 동시에 들어왔을 때
 *
 *      full: Buffer가 가득 찼는지 여부 판단
 *              tail+1이 head와 같을 때
 *
 *      empty: Buffer가 비어 있는지 여부 판단
 *              tail가 head와 같을 때
 *      
 *      can_enqueue: Enqueue가 가능한 조건
 *              Buffer가 가득 차지 않았거나, Overwrite 가능하거나, enqueue와 dequeue 동시 입력일 때
 *      
 *      can_dequeue: Dequeue가 가능한 조건
 *              Buffer가 비어 있지 않거나, enqueue와 dequeue 동시 입력일 때
 *      
 *      do_enqueue: Enqueue 진행 신호
 *              Enqueue 입력이 들어오고, enqueue가 가능할 때
 *      
 *      do_dequeue: Dequeue 진행 신호
 *              Dequeue 입력이 들어오고, dequeue가 가능할 때
 *      
 *      tail_next: tail pointer의 다음 값
 *              Enqueue 진행 신호를 받을 때 증가
 *      
 *      head_next: head pointer의 다음 값
 *              Dequeue 진행 신호를 받거나, Overwrite 가능 + enqueue 진행 신호 + buffer full일 때 증가
 */
reg is_enq_deq_simult;
reg [ADDR_BIT-1:0] tail_circular_inc, head_circular_inc; 
reg [ADDR_BIT-1:0] tail_next, head_next;
reg can_enqueue, can_dequeue;
reg do_enqueue, do_dequeue;
always @(*) begin
    // Enqueue와 dequeue 신호 동시 입력 여부 판단
    is_enq_deq_simult = (enqueue_i & dequeue_i);

    // Circular incremented value of tail and head
    tail_circular_inc = (tail == MEM_DEPTH-1) ? 0 : tail + 1;
    head_circular_inc = (head == MEM_DEPTH-1) ? 0 : head + 1;

    // Buffer state
    full  = (head == tail_circular_inc);
    empty = (head == tail);

    // Enqueue, dequeue가 가능한지 판단
    can_enqueue = ~full  | is_enq_deq_simult | OVERWRITABLE;
    can_dequeue = ~empty | is_enq_deq_simult;

    // Enqueue, dequeue 진행 신호 생성
    do_enqueue = enqueue_i & can_enqueue;
    do_dequeue = dequeue_i & can_dequeue;

    // 다음 tail, head 값 결정
    tail_next = do_enqueue ? tail_circular_inc : tail;
    head_next = (do_dequeue | (OVERWRITABLE & do_enqueue & full)) ? head_circular_inc : head;
end

// Head, tail transition logic
always @(posedge clk or negedge rstn) begin
    if (~rstn) begin
        tail <= {($clog2(LENGTH+1)){1'b0}};
        head <= {($clog2(LENGTH)){1'b0}};
    end
    else begin
        tail <= tail_next;
        head <= head_next;
    end
end

// Enqueue logic
// Reset logic 사용하지 않아야 RAM으로 합성됨.
always @(posedge clk) begin
    if (do_enqueue)
        buffer_m[tail] <= data_i;
end

// Dequeue logic
always @(*) begin
    if (do_dequeue)
        data_o = buffer_m[head];
    else
        data_o = {(WIDTH){1'b0}};
end

endmodule