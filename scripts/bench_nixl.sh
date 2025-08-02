#!/bin/bash
### Common configs
# 8589934592 (8GB)
total_sizes_gb=(24G)
max_batch_size=16
start_batch_size=1
num_threads=(1 2 4 8 16)
declare -A total_sizes_bytes=(
    [8G]=8589934592
    [32G]=34359738368
    [24G]=25769803776
)

etcd_endpoints="http://10.52.3.209:2379"

REPEAT_TIMES=3

########################## Test-Case 1: Exchange data between DRAM and Local STORAGE ###############
bench_mem2file() {
    BACKENDS=(POSIX GDS)
    LOG_PATH="/home/cc/shared_cc/nixlbench/bin/results/mem2file/"

    if [ ! -d "$LOG_PATH" ]; then
        mkdir -p "$LOG_PATH"
    fi

    posix_api_types=("AIO")
    storage_enable_direct=(0 1)

    echo "Starting benchmark for mem2file with backends: ${BACKENDS[*]}"
    
    for backend in "${BACKENDS[@]}"; do
        if [ "$backend" == "POSIX" ]; then
            for posix_api_type in "${posix_api_types[@]}"; do
                for enable_direct in "${storage_enable_direct[@]}"; do
                    for total_size_gb in "${total_sizes_gb[@]}"; do
                        for num_thread in "${num_threads[@]}"; do
                            for repeat_id in $(seq 1 $REPEAT_TIMES); do
                                
                                echo "Benchmark nixl with POSIX backend using ${posix_api_type}: total_size=$total_size_gb, start_batch_size=$start_batch_size, max_batch_size=$max_batch_size, num_thread=$num_thread, enable_direct=$enable_direct"
                                total_size_bytes=${total_sizes_bytes[$total_size_gb]}
                                ./nixlbench --worker_type nixl --runtime_type=ETCD --etcd-endpoints ${etcd_endpoints} \
                                    --backend $backend --device_list all --filepath /mnt/nvme/jye/ \
                                    --initiator_seg_type DRAM --op_type WRITE \
                                    --total_buffer_size $total_size_bytes --max_batch_size $max_batch_size \
                                    --start_batch_size $start_batch_size --num_threads $num_thread \
                                    --posix_api_type $posix_api_type --storage_enable_direct=$enable_direct \
                                    > "$LOG_PATH/mem2file_POSIX_${posix_api_type}_${enable_direct}_W_t-${total_size_gb}_th-${num_thread}_${repeat_id}.log" 2>&1

                                echo "Finished WRITE OPS"
                                sleep 5
                            done
                            
                            for repeat_id in $(seq 1 $REPEAT_TIMES); do
                                echo "Starting READ OPS"
                                ./nixlbench --worker_type nixl --runtime_type=ETCD --etcd-endpoints ${etcd_endpoints} \
                                    --backend $backend --device_list all --filepath /mnt/nvme/jye/ \
                                    --initiator_seg_type DRAM --op_type READ \
                                    --total_buffer_size $total_size_bytes --max_batch_size $max_batch_size \
                                    --start_batch_size $start_batch_size --num_threads $num_thread \
                                    --posix_api_type $posix_api_type --storage_enable_direct=$enable_direct \
                                    > "$LOG_PATH/mem2file_POSIX_${posix_api_type}_${enable_direct}_R_t-${total_size_gb}_th-${num_thread}_${repeat_id}.log" 2>&1
                                echo "Finished READ OPS"
                                sleep 5
                            done
                        done
                    done
                done
            done
        else
            ### GDS backend
            for enable_direct in "${storage_enable_direct[@]}"; do
                for total_size_gb in "${total_sizes_gb[@]}"; do
                    for num_thread in "${num_threads[@]}"; do
                        for repeat_id in $(seq 1 $REPEAT_TIMES); do
                            # GDS backend does not support DRAM initiator with VRAM target, so we use DRAM initiator and DRAM target
                            echo "Benchmark nixl with GDS backend: total_size=$total_size_gb, start_batch_size=$start_batch_size, max_batch_size=$max_batch_size, num_thread=$num_thread"
                            total_size_bytes=${total_sizes_bytes[$total_size_gb]}
                            ./nixlbench --worker_type nixl --runtime_type=ETCD --etcd-endpoints ${etcd_endpoints} \
                                --backend $backend --device_list all --filepath /mnt/nvme/jye/ \
                                --initiator_seg_type DRAM --op_type WRITE \
                                --total_buffer_size $total_size_bytes --max_batch_size $max_batch_size \
                                --start_batch_size $start_batch_size --num_threads $num_thread --storage_enable_direct=$enable_direct \
                                > "$LOG_PATH/mem2file_GDS_${enable_direct}_W_t-${total_size_gb}_th-${num_thread}_${repeat_id}.log" 2>&1

                            echo "Finished WRITE OPS between DRAM and Local STORAGE"
                            sleep 5
                        done
                        for repeat_id in $(seq 1 $REPEAT_TIMES); do
                            echo "Starting READ OPS between DRAM and Local STORAGE"
                            ./nixlbench --worker_type nixl --runtime_type=ETCD --etcd-endpoints ${etcd_endpoints} \
                                --backend $backend --device_list all --filepath /mnt/nvme/jye/ \
                                --initiator_seg_type DRAM --op_type READ \
                                --total_buffer_size $total_size_bytes --max_batch_size $max_batch_size \
                                --start_batch_size $start_batch_size --num_threads $num_thread --storage_enable_direct=$enable_direct \
                                > "$LOG_PATH/mem2file_GDS_${enable_direct}_R_t-${total_size_gb}_th-${num_thread}.log" 2>&1
                            echo "Finished READ OPS between DRAM and Local STORAGE"
                            sleep 5
                        done
                    done
                done
            done
        fi
    done
}


########################## Test-Case 2: Exchange data between VRAM and Local STORAGE ###############
bench_vram2file() {
    backend=GDS
    LOG_PATH="/home/cc/shared_cc/nixlbench/bin/results/vram2file/"
    if [ ! -d "$LOG_PATH" ]; then
        mkdir -p "$LOG_PATH"
    fi

    storage_enable_direct=(0 1)
    # storage_enable_direct=(1)
    echo "Starting benchmark for vram2file with backend: $backend"
    for enable_direct in "${storage_enable_direct[@]}"; do 
        for total_size_gb in "${total_sizes_gb[@]}"; do
            tmp_max_batch_size=$max_batch_size 
            for num_thread in "${num_threads[@]}"; do
                echo "Benchmark nixl with GDS backend: total_size=$total_size_gb, start_batch_size=$start_batch_size, max_batch_size=$max_batch_size, num_thread=$num_thread"
                if [ $num_thread -gt 1 ]; then
                    tmp_max_batch_size=1
                fi
                for repeat_id in $(seq 1 $REPEAT_TIMES); do
                    total_size_bytes=${total_sizes_bytes[$total_size_gb]}
                    ./nixlbench --worker_type nixl --runtime_type=ETCD --etcd-endpoints ${etcd_endpoints} \
                        --backend $backend --device_list all --filepath /mnt/nvme/jye/ \
                        --initiator_seg_type VRAM --op_type WRITE \
                        --total_buffer_size $total_size_bytes --max_batch_size $tmp_max_batch_size \
                        --start_batch_size $start_batch_size --num_threads $num_thread --storage_enable_direct=$enable_direct \
                        > "$LOG_PATH/vmem2file_GDS_${enable_direct}_W_t-${total_size_gb}_th-${num_thread}_${repeat_id}.log" 2>&1

                    echo "Finished WRITE OPS between VRAM and Local STORAGE"
                    sleep 5
                done
                for repeat_id in $(seq 1 $REPEAT_TIMES); do
                    echo "Starting READ OPS between VRAM and Local STORAGE"
                    ./nixlbench --worker_type nixl --runtime_type=ETCD --etcd-endpoints ${etcd_endpoints} \
                        --backend $backend --device_list all --filepath /mnt/nvme/jye/ \
                        --initiator_seg_type VRAM --op_type READ \
                        --total_buffer_size $total_size_bytes --max_batch_size $tmp_max_batch_size \
                        --start_batch_size $start_batch_size --num_threads $num_thread --storage_enable_direct=$enable_direct \
                        > "$LOG_PATH/vmem2file_GDS_${enable_direct}_R_t-${total_size_gb}_th-${num_thread}_${repeat_id}.log" 2>&1
                    echo "Finished READ OPS between VRAM and Local STORAGE"
                    sleep 5
                done
            done
        done
    done
}

########################## Test-Case 3: Exchange data between DRAM and DRAM using UCX ###############
bench_dram2dram_ucx() {
    backend=UCX
    LOG_PATH="/home/cc/shared_cc/nixlbench/bin/results/dram2dram_ucx/"
    if [ ! -d "$LOG_PATH" ]; then
        mkdir -p "$LOG_PATH"
    fi

    echo "Starting benchmark for dram2dram with backend: $backend"
    for total_size_gb in "${total_sizes_gb[@]}"; do
        for repeat_id in $(seq 1 $REPEAT_TIMES); do
            tmp_max_batch_size=$max_batch_size
            ### only test with 1 thread for UCX since it is crashed when runnign multiple threads 
            num_thread=1
            echo "Benchmark nixl with UCX backend: total_size=$total_size_gb, start_batch_size=$start_batch_size, max_batch_size=$max_batch_size, num_thread=$num_thread"
            total_size_bytes=${total_sizes_bytes[$total_size_gb]}
            exec_cmd="cd /home/cc/shared_cc/nixlbench/bin && source nixl_env && mkdir -p $LOG_PATH && hostname_var=\`hostname\`; ./nixlbench \
                --worker_type nixl --runtime_type=ETCD --etcd-endpoints ${etcd_endpoints} \
                --backend $backend --device_list all \
                --initiator_seg_type DRAM --target_seg_type DRAM --op_type WRITE \
                --total_buffer_size $total_size_bytes --max_batch_size $tmp_max_batch_size \
                --start_batch_size $start_batch_size --num_threads $num_thread \
                > \"$LOG_PATH/dram2dram_ucx_W_t-${total_size_gb}_th-${num_thread}_${repeat_id}_\${hostname_var}.log\" 2>&1"

            # parallel-ssh -h ./nodes -i "$exec_cmd"
            parallel-ssh -t 60 -h ./nodes -i "killall -9 nixlbench && sleep 1"
            sleep 5
            parallel-ssh -t 1800 -h ./nodes -i "$exec_cmd"
            # parallel-ssh -h ./nodes -i "date"

            echo "Finished Data transfer between DRAM and DRAM"
            sleep 5
        done
    done
}

########################## Test-Case 3: Exchange data between VRAM and VRAM using UCX ###############
bench_vram2vram_ucx() {
    backend=UCX
    LOG_PATH="/home/cc/shared_cc/nixlbench/bin/results/vram2vram_ucx/"
    if [ ! -d "$LOG_PATH" ]; then
        mkdir -p "$LOG_PATH"
    fi

    echo "Starting benchmark for vram2vram with backend: $backend"
    for total_size_gb in "${total_sizes_gb[@]}"; do
        for repeat_id in $(seq 1 $REPEAT_TIMES); do
            tmp_max_batch_size=$max_batch_size
            ### only test with 1 thread for UCX since it is crashed when runnign multiple threads 
            num_thread=1
            echo "Benchmark nixl with GDS backend: total_size=$total_size_gb, start_batch_size=$start_batch_size, max_batch_size=$max_batch_size, num_thread=$num_thread"
            total_size_bytes=${total_sizes_bytes[$total_size_gb]}
            exec_cmd="cd /home/cc/shared_cc/nixlbench/bin && source nixl_env && mkdir -p $LOG_PATH && hostname_var=\`hostname\`; ./nixlbench \
                --worker_type nixl --runtime_type=ETCD --etcd-endpoints ${etcd_endpoints} \
                --backend $backend --device_list all \
                --initiator_seg_type VRAM --target_seg_type VRAM --op_type WRITE \
                --total_buffer_size $total_size_bytes --max_batch_size $tmp_max_batch_size \
                --start_batch_size $start_batch_size --num_threads $num_thread \
                > \"$LOG_PATH/vram2vram_ucx_W_t-${total_size_gb}_th-${num_thread}_${repeat_id}_\${hostname_var}.log\" 2>&1"

            # parallel-ssh -h ./nodes -i "$exec_cmd"
            parallel-ssh -t 60 -h ./nodes -i "killall -9 nixlbench && sleep 1"
            sleep 5 
            parallel-ssh -t 1800 -h ./nodes -i "$exec_cmd"
            # parallel-ssh -h ./nodes -i "date"

            echo "Finished Data transfer between VRAM and VRAM"
            sleep 5
        done
    done
}

########################## Test-Case 4: Exchange data between VRAM and DRAM using UCX in the same node ###############
# bench_vram2dram_ucx_single_node() {
#     backend=UCX
#     LOG_PATH="/home/cc/shared_cc/nixlbench/bin/results/vram2dram_ucx_sn/"
#     if [ ! -d "$LOG_PATH" ]; then
#         mkdir -p "$LOG_PATH"
#     fi

#     echo "Starting benchmark for vram2dram with backend: $backend"
#     for total_size_gb in "${total_sizes_gb[@]}"; do
#         tmp_max_batch_size=$max_batch_size
#         ### only test with 1 thread for UCX since it is crashed when runnign multiple threads 
#         num_thread=1
#         echo "Benchmark nixl with UCX backend: total_size=$total_size_gb, start_batch_size=$start_batch_size, max_batch_size=$max_batch_size, num_thread=$num_thread"
#         total_size_bytes=${total_sizes_bytes[$total_size_gb]}
#         exec_cmd_0="./nixlbench \
#             --worker_type nixl --runtime_type=ETCD --etcd-endpoints ${etcd_endpoints} \
#             --backend $backend --device_list all \
#             --initiator_seg_type VRAM --target_seg_type DRAM --op_type WRITE \
#             --total_buffer_size $total_size_bytes --max_batch_size $tmp_max_batch_size \
#             --start_batch_size $start_batch_size --num_threads $num_thread \
#             > \"$LOG_PATH/vram2dram_ucx_W_t-${total_size_gb}_th-${num_thread}_0.log\" 2>&1"

#         exec_cmd_1="./nixlbench \
#             --worker_type nixl --runtime_type=ETCD --etcd-endpoints ${etcd_endpoints} \
#             --backend $backend --device_list all \
#             --initiator_seg_type VRAM --target_seg_type DRAM --op_type WRITE \
#             --total_buffer_size $total_size_bytes --max_batch_size $tmp_max_batch_size \
#             --start_batch_size $start_batch_size --num_threads $num_thread \
#             > \"$LOG_PATH/vram2dram_ucx_W_t-${total_size_gb}_th-${num_thread}_1.log\" 2>&1"

#         # parallel-ssh -h ./nodes -i "$exec_cmd"
#         parallel-ssh -t 60 -h ./nodes -i "killall -9 nixlbench && sleep 1"
#         sleep 5 
#         parallel-ssh -t 1800 -h ./nodes -i "$exec_cmd"
#         # parallel-ssh -h ./nodes -i "date"

#         echo "Finished Data transfer between VRAM and DRAM"
#         sleep 5
#     done
# }

# ########################## Test-Case 5: Exchange data between VRAM and DRAM using UCX across two nodes ###############
# bench_vram2dram_ucx_two_nodes() {
#     backend=UCX
#     LOG_PATH="/home/cc/shared_cc/nixlbench/bin/results/vram2dram_ucx/"
#     if [ ! -d "$LOG_PATH" ]; then
#         mkdir -p "$LOG_PATH"
#     fi

#     echo "Starting benchmark for vram2dram with backend: $backend"
#     for total_size_gb in "${total_sizes_gb[@]}"; do
#         tmp_max_batch_size=$max_batch_size
#         ### only test with 1 thread for UCX since it is crashed when runnign multiple threads 
#         num_thread=1
#         echo "Benchmark nixl with GDS backend: total_size=$total_size_gb, start_batch_size=$start_batch_size, max_batch_size=$max_batch_size, num_thread=$num_thread"
#         total_size_bytes=${total_sizes_bytes[$total_size_gb]}
#         exec_cmd="cd /home/cc/shared_cc/nixlbench/bin && source nixl_env && mkdir -p $LOG_PATH && hostname_var=\`hostname\`; ./nixlbench \
#             --worker_type nixl --runtime_type=ETCD --etcd-endpoints ${etcd_endpoints} \
#             --backend $backend --device_list all \
#             --initiator_seg_type VRAM --target_seg_type DRAM --op_type WRITE \
#             --total_buffer_size $total_size_bytes --max_batch_size $tmp_max_batch_size \
#             --start_batch_size $start_batch_size --num_threads $num_thread \
#             > \"$LOG_PATH/vram2dram_ucx_W_t-${total_size_gb}_th-${num_thread}_\${hostname_var}.log\" 2>&1"

#         # parallel-ssh -h ./nodes -i "$exec_cmd"
#         parallel-ssh -t 60 -h ./nodes -i "killall -9 nixlbench && sleep 1"
#         sleep 5 
#         parallel-ssh -t 1800 -h ./nodes -i "$exec_cmd"
#         # parallel-ssh -h ./nodes -i "date"

#         echo "Finished Data transfer between VRAM and DRAM"
#         sleep 5
#     done
# }

##################################################################################
bench_mem2file
# bench_vram2file
# bench_dram2dram_ucx
# bench_vram2vram_ucx


