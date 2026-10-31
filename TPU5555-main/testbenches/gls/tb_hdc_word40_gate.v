`timescale 1ns / 1ps

// Changes for the TPU5555 post-layout simulation (defaults as delivered):
// - define DATA_DIR: location of the vector files and TestData
// - plusargs +TRAIN_PER_CLASS=n +TEST_PER_CLASS=n (0 = all samples, default 1)
//   and +PRED_FILE=path (one "sample label prediction" line per test sample)
// - a dummy finalize after reset (datasheet power-up caveat); disable with
//   define NO_DUMMY_FINALIZE
`ifndef DATA_DIR
`define DATA_DIR "../../"
`endif

module tb_hdc_word40_gate;
    localparam G_D             = 1000;
    localparam TRAIN_PER_CLASS = 1;   // defaults, see plusargs
    localparam TEST_PER_CLASS  = 1;
    localparam real CLK_PERIOD_NS  = 33.333;
    localparam real SCLK_PERIOD_NS = 97.0;
    localparam real RESET_HOLD_NS  = 5000.0;

    localparam IM_PATH          = {`DATA_DIR, "position-vectors.txt"};
    localparam CM_PATH          = {`DATA_DIR, "value_vectors.txt"};
    localparam TRAIN_EMG_PATH   = {`DATA_DIR, "TestData/P01_Noshy/training_emg.csv"};
    localparam TRAIN_LABEL_PATH = {`DATA_DIR, "TestData/P01_Noshy/training_labels.csv"};
    localparam TEST_EMG_PATH    = {`DATA_DIR, "TestData/P01_Noshy/testing_emg.csv"};
    localparam TEST_LABEL_PATH  = {`DATA_DIR, "TestData/P01_Noshy/testing_labels.csv"};

    localparam N      = 32;
    localparam K      = 5;
    localparam M      = 40;
    localparam CHUNKS = (G_D + 39) / 40;

    reg  clk_i  = 1'b0;
    reg  rstn_i = 1'b0;
    reg  sclk_i = 1'b0;
    reg  mosi_i = 1'b0;
    reg  cs_n_i = 1'b1;
    wire led_o;
    wire miso_o;

    hdc_word40_top uut (
        .clk_i (clk_i),
        .rstn_i(rstn_i),
        .sclk_i(sclk_i),
        .mosi_i(mosi_i),
        .cs_n_i(cs_n_i),
        .led_o (led_o),
        .miso_o(miso_o)
    );

`ifdef SDF_FILE
    initial $sdf_annotate(`SDF_FILE, uut);
`endif

    always #(CLK_PERIOD_NS / 2.0) clk_i = ~clk_i;

`ifdef PROGRESS
    // Wall-clock independent progress marker for speed measurements.
    always #100000 begin $display("progress: %0t", $time); $fflush; end
`endif
`ifdef VCD
    // Waveform of the start-up (reset, first commands); build with --trace.
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb_hdc_word40_gate);
        #(`VCD) $finish;
    end
`endif
`ifdef TRACE
    // Protocol trace (compare RTL and gate level line by line).
    `define TR(msg) begin $display msg; $fflush; end
`else
    `define TR(msg) begin end
`endif

    task spi_begin;
        begin cs_n_i = 1'b0; #(SCLK_PERIOD_NS / 2.0); end
    endtask

    task spi_end;
        begin cs_n_i = 1'b1; #(SCLK_PERIOD_NS / 2.0); end
    endtask

    task automatic spi_pair(input [7:0] tx0, input [7:0] tx1, output [15:0] rx);
        reg [15:0] tx;
        integer i;
        begin
            tx = {tx0, tx1};
            for (i = 15; i >= 0; i = i - 1) begin
                mosi_i = tx[i];
                #(SCLK_PERIOD_NS / 2.0);
                sclk_i = 1'b1;
                #(SCLK_PERIOD_NS / 2.0);
                if (miso_o !== 1'b0 && miso_o !== 1'b1)
                    $fatal(1, "miso_o is '%b' at %0t", miso_o, $time);
                rx[i] = miso_o;
                sclk_i = 1'b0;
                #(SCLK_PERIOD_NS / 2.0);
            end
        end
    endtask

    task automatic send(input [7:0] data);
        reg [15:0] rx;
        begin spi_pair(8'hA5, data, rx); end
    endtask

    task automatic receive(output [7:0] data);
        reg [15:0] rx;
        integer polls;
        begin
            rx = 16'h0;
            for (polls = 0; rx[15:8] != 8'h01; polls = polls + 1) begin
                if (polls == 200000)
                    $fatal(1, "SPI poll timeout at %0t", $time);
                if (polls > 0 && polls % 1000 == 0)
                    `TR(("  still polling: %0d polls at %0t", polls, $time))
                spi_pair(8'h00, 8'h00, rx);
            end
            data = rx[7:0];
        end
    endtask

    task automatic command(input [7:0] cmd, input integer nargs, input [31:0] args);
        reg [7:0] ack;
        integer i;
        begin
            spi_begin;
            send(cmd);
            for (i = 0; i < nargs; i = i + 1)
                send(args[8*i +: 8]);
            receive(ack);
            spi_end;
            `TR(("cmd %s nargs %0d -> ack %h at %0t", cmd, nargs, ack, $time))
        end
    endtask

    task automatic receive_prediction(output integer pred);
        reg [7:0] b;
        begin
            spi_begin;
            receive(b);
            spi_end;
            pred = b[2:0];
            `TR(("result byte %h at %0t", b, $time))
        end
    endtask

    reg [39:0] words [0:CHUNKS-1];

    task automatic load_memory(input [7:0] mem_sel, input integer rows, input [8*256-1:0] path);
        reg [7:0] ack;
        integer fd, row, c, col, w, b;
        begin
            fd = $fopen(path, "r");
            for (row = 0; row < rows; row = row + 1) begin
                for (w = 0; w < CHUNKS; w = w + 1)
                    words[w] = 40'b0;
                c = $fgetc(fd);
                while (c == 10 || c == 13)
                    c = $fgetc(fd);
                for (col = 0; c != 10 && c != -1; c = $fgetc(fd))
                    if (c != 13) begin
                        if (col < CHUNKS * 40)
                            words[col / 40][39 - col % 40] = (c == "1");
                        col = col + 1;
                    end
                spi_begin;
                send("W");
                send(mem_sel);
                send((row * CHUNKS) % 256);
                send((row * CHUNKS) / 256);
                send(CHUNKS % 256);
                send(CHUNKS / 256);
                for (w = 0; w < CHUNKS; w = w + 1)
                    for (b = 0; b < 5; b = b + 1)
                        send(words[w][8*b +: 8]);
                receive(ack);
                spi_end;
                `TR(("load %s row %0d -> ack %h at %0t", mem_sel, row, ack, $time))
            end
            $fclose(fd);
        end
    endtask

    integer features [0:N-1];

    task automatic read_features(input integer fd, output ok);
        integer i, q, sep;
        real value;
        begin
            ok = 1'b1;
            for (i = 0; i < N && ok; i = i + 1)
                if ($fscanf(fd, "%f", value) != 1) begin
                    ok = 1'b0;
                end else begin
                    sep = $fgetc(fd);
                    q = value * 16384.0 + 16384.0;
                    features[i] = (q < 0) ? 0 : (q > 32768) ? 32768 : q;
                end
        end
    endtask

    task automatic send_features;
        reg [7:0] ack;
        reg [31:0] q;
        integer i, b;
        begin
            spi_begin;
            send("B");
            for (i = 0; i < N; i = i + 1) begin
                q = features[i];
                for (b = 0; b < 4; b = b + 1)
                    send(q[8*b +: 8]);
            end
            receive(ack);
            spi_end;
            `TR(("features -> ack %h at %0t", ack, $time))
        end
    endtask

    task automatic skip_line(input integer fd);
        reg [8*4096-1:0] line;
        integer r;
        begin r = $fgets(line, fd); end
    endtask

    task automatic finalize(input integer label);
        integer ignored;
        begin
            command("L", 1, label);
            command("X", 0, 0);
            receive_prediction(ignored);
        end
    endtask

    integer class_cnt [0:K-1];
    integer correct;
    integer pred_fd;

    task automatic run_phase(input train, input [8*256-1:0] emg_path,
                             input [8*256-1:0] label_path, input integer per_class,
                             output integer samples);
        integer emg_fd, lab_fd, label, pred, current, full, i;
        reg ok;
        begin
            emg_fd = $fopen(emg_path, "r");
            lab_fd = $fopen(label_path, "r");
            skip_line(emg_fd);
            skip_line(lab_fd);
            for (i = 0; i < K; i = i + 1) class_cnt[i] = 0;
            command("M", 1, train);
            samples = 0;
            current = -1;
            full    = 0;
            read_features(emg_fd, ok);
            while (ok && full < K && $fscanf(lab_fd, "%d", label) == 1) begin
                if (per_class == 0 || class_cnt[label] < per_class) begin
                    if (train && current != -1 && label != current)
                        finalize(current);
                    current = label;
                    if (train)
                        command("L", 1, label);
                    send_features;
                    receive_prediction(pred);
                    if (!train) begin
                        $display("test sample %0d: label %0d, predicted %0d", samples, label, pred);
                        $fdisplay(pred_fd, "%0d %0d %0d", samples, label, pred);
                        if (pred == label)
                            correct = correct + 1;
                    end
                    samples = samples + 1;
                    if (train && samples % 100 == 0)
                        $display("training sample %0d at %0t", samples, $time);
                    class_cnt[label] = class_cnt[label] + 1;
                    if (per_class > 0 && class_cnt[label] == per_class)
                        full = full + 1;
                end
                read_features(emg_fd, ok);
            end
            if (train && current != -1)
                finalize(current);
            $fclose(emg_fd);
            $fclose(lab_fd);
        end
    endtask

    integer train_samples, test_samples;
    integer train_per_class, test_per_class;
    reg [8*256-1:0] pred_file;

    initial begin
        correct = 0;
        #(RESET_HOLD_NS);
        rstn_i = 1'b1;
        #(20 * CLK_PERIOD_NS);

        if (!$value$plusargs("TRAIN_PER_CLASS=%d", train_per_class)) train_per_class = TRAIN_PER_CLASS;
        if (!$value$plusargs("TEST_PER_CLASS=%d", test_per_class)) test_per_class = TEST_PER_CLASS;
        if (!$value$plusargs("PRED_FILE=%s", pred_file)) pred_file = "predictions.txt";
        pred_fd = $fopen(pred_file, "w");
`ifndef NO_DUMMY_FINALIZE
        // SRAM contents (incl. the class counters) are undefined at power-up;
        // one finalize clears the counters (writes AM row 0, rewritten by training).
        command("M", 1, 1);
        finalize(0);
`endif
        load_memory("I", N, IM_PATH);
        load_memory("C", M, CM_PATH);
        run_phase(1'b1, TRAIN_EMG_PATH, TRAIN_LABEL_PATH, train_per_class, train_samples);
        run_phase(1'b0, TEST_EMG_PATH, TEST_LABEL_PATH, test_per_class, test_samples);

        $display("%0d training, %0d test samples, %0d/%0d correct",
                 train_samples, test_samples, correct, test_samples);
        $fclose(pred_fd);
        $finish;
    end
endmodule
