#!/bin/bash
#set -x
KB=$((1024))
MB=$(($KB*1024))
GB=$(($MB*1024))
# APP_PREFIX=sudo
APP_PREFIX="numactl --cpunodebind=0 --membind=0"
# APP_PREFIX=""

db_path=$(pwd)
db_bench=$db_path/build
db_include=$db_path/include
ycsb_path=$db_path/ycsbc

sata_path=/tmp/pm_test
ssd_path=/media/nvme1/pm_test
pm_path=/mnt/pmem0.1/pm_test
# leveldb_path=/tmp/leveldb-wzh
leveldb_path=$pm_path
output_path=$db_path/output
output_file=$output_path/result.out

export CPLUS_INCLUDE_PATH=$db_path/include:$CPLUS_INCLUDE_PATH
export LIBRARY_PATH=$db_path/build:$LIBRARY_PATH

benchmarks="overwrite,readrandom,readseq,stats"
# benchmarks2="fillseqNofresh,readrandom,readseq,stats"
ycsb_input=1KB_ALL

num_thread=1
value_size=1024
num_kvs=$((10*$MB))
write_buffer_size=$((64*$MB))
max_file_size=$((128*$MB))
pm_size=$((180*$GB))
bucket_nums=$((4*$MB)) # bucket_nums * 4 > nums_kvs
use_pm=1
flush_ssd=0
throughput=0

read_key_num="1000000"
# disable compression
comp_ratio="1"
# theoretical KV num in penultimate layer
bench_keys_per_datatable="2097152"
# dram node in numa
numa_dram_node=0
# nvm node in numa
numa_nvm_node=3
# nvm next node in numa, we can use -1 to disable this
numa_nvm_next_node=-1

WRITE10G() {
    pm_path=$sata_path
    leveldb_path=$sata_path
    # leveldb_path=$pm_path;
    value_size=1000
    num_thread=1
    num_kvs=$((10*$MB))
    # write_buffer_size=$((3*$MB))
    max_file_size=$((100*$MB))
    pm_size=$((20*$GB))
    bucket_nums=$((4*$MB)) # bucket_nums * 4 > nums_kvs
}
WRITE80G_FLUSHSSD() {
    leveldb_path=$ssd_path;
    value_size=$((4*$KB))
    num_kvs=$((80*$GB / $value_size))
    pm_size=$((8*$GB))
    bucket_nums=$((8*$MB)) # bucket_nums * 4 > nums_kvs
    flush_ssd=1
}
WRITE80G-1KB-THROUGHPUT() {
    value_size=$((1*$KB))
    num_kvs=$((80*$GB / $value_size))
    bucket_nums=$((32*$MB)) # bucket_nums * 4 > nums_kvs
    throughput=1
}
WRITE80G-4KB-THROUGHPUT() {
    value_size=$((4*$KB))
    num_kvs=$((80*$GB / $value_size))
    bucket_nums=$((8*$MB)) # bucket_nums * 4 > nums_kvs
    throughput=1
}
WRITE80G-256B() {
    value_size=$((256))
    num_kvs=$((80*$GB / $value_size))
    bucket_nums=$((128*$MB)) # bucket_nums * 4 > nums_kvs
}
WRITE80G() {
    value_size=$((1*$KB))
    num_kvs=$((80*$GB / $value_size))
    bucket_nums=$((32*$MB)) # bucket_nums * 4 > nums_kvs
}
WRITE80G-4K() {
    value_size=$((4*$KB))
    num_kvs=$((80*$GB / $value_size))
    bucket_nums=$((8*$MB)) # bucket_nums * 4 > nums_kvs
}
WRITE80G-16K() {
    value_size=$((16*$KB))
    num_kvs=$((80*$GB / $value_size))
    bucket_nums=$((8*$MB)) # bucket_nums * 4 > nums_kvs
}
WRITE80G-64K() {
    value_size=$((64*$KB))
    num_kvs=$((80*$GB / $value_size))
    bucket_nums=$((8*$MB)) # bucket_nums * 4 > nums_kvs
}
WRITE80G_8GNVM() {
    leveldb_path=$ssd_path;
    value_size=$((4*$KB))
    num_kvs=$((80*$GB / $value_size))
    pm_size=$((8*$GB))
    bucket_nums=$((8*$MB)) # bucket_nums * 4 > nums_kvs
    flush_ssd=1
}
WRITE80G_16GNVM() {
    leveldb_path=$ssd_path;
    value_size=$((4*$KB))
    num_kvs=$((80*$GB / $value_size))
    pm_size=$((16*$GB))
    bucket_nums=$((8*$MB)) # bucket_nums * 4 > nums_kvs
    flush_ssd=1
}
WRITE80G_32GNVM() {
    leveldb_path=$ssd_path;
    value_size=$((4*$KB))
    num_kvs=$((80*$GB / $value_size))
    pm_size=$((32*$GB))
    bucket_nums=$((8*$MB)) # bucket_nums * 4 > nums_kvs
    flush_ssd=1
}
WRITE80G_64GNVM() {
    leveldb_path=$ssd_path;
    value_size=$((4*$KB))
    num_kvs=$((80*$GB / $value_size))
    pm_size=$((64*$GB))
    bucket_nums=$((8*$MB)) # bucket_nums * 4 > nums_kvs
    flush_ssd=1
}

WRITE100G() {
    leveldb_path=$pm_path;
    value_size=1000
    num_thread=1
    num_kvs=$((100*$MB))
    # write_buffer_size=$((40*$MB))
    max_file_size=$((1024*$MB))
    pm_size=$((200*$GB))
    bucket_nums=$((40*$MB)) # bucket_nums * 4 > nums_kvs
    use_pm=1
}

RUN_DB_BENCH() {
    CLEAN_DB
    if [ -f "$output_file" ]; then
        rm $output_file
        echo "delete output_file: $output_file"
    fi
    parameters="--benchmarks=$benchmarks \
                --num=$num_kvs \
                --value_size=$value_size \
                --write_buffer_size=$write_buffer_size \
                --reads=$read_key_num \
                --compression_ratio=$comp_ratio \
                --db=$leveldb_path \
                --keys_per_datatable=$bench_keys_per_datatable \
                --dram_node=$numa_dram_node \
                --nvm_node=$numa_nvm_node \
                --nvm_next_node=$numa_nvm_next_node \
                --max_file_size=$max_file_size \
                --throughput=$throughput \
                "
    cmd="$APP_PREFIX $db_bench/db_bench $parameters >> $output_file"
    echo $cmd >> $output_file
    echo $cmd
    eval $cmd
}

RUN_YCSB(){
    CLEAN_DB
    if [ -f "$output_file" ]; then
        rm $output_file
        echo "delete output_file: $output_file"
    fi
    cmd="$APP_PREFIX $ycsb_path/ycsbc $ycsb_path/input/$ycsb_input >> $output_file"
    echo $cmd >> $output_file
    echo $cmd
    eval $cmd
}

CLEAN_DB() {
  if [ -z "$pm_path" ]
  then
        echo "PM path empty."
        exit
  fi
  if [ -z "$leveldb_path" ]
  then
        echo "DB path empty."
        exit
  fi
  rm -rf ${leveldb_path:?}/*
  rm -rf ${pm_path:?}/*
#   mkdir -p $pm_path
}

SET_OUTPUT_PATH() {
    if [ ! -d "$output_path" ]; then
        # 如果目录不存在，则创建目录
        mkdir $output_path
        echo "Created output_path: $output_path"
    fi
    # else
    #     # 如果目录已存在，则清空目录下的所有文件
    #     rm -rf "${output_path:?}/"*
    #     echo "Cleared output_path: $output_path"
    # fi
    # touch $output_file
    # echo "Created file: $output_file"
}

MAKE() {
  if [ ! -d "$db_bench" ]; then
    # 如果目录不存在，则创建目录
    mkdir $db_bench
  fi
  cd $db_bench
  cmake -DCMAKE_BUILD_TYPE=Release .. 
#   cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo .. 

  make -j64
  cd ..
  cd $ycsb_path
  #make clean
  make
  cd ..
}

DB_BENCH_TEST() {
    echo "------------db_bench------------"
    benchmarks="fillrandom,readrandom,stats"
    # echo "------256B random write/read-----"
    # output_file=$output_path/Rnd_NVM_256B
    # WRITE80G-256B
    # RUN_DB_BENCH

    echo "------1KB random write/read-----"
    output_file=$output_path/Rnd_NVM_1K
    WRITE80G
    RUN_DB_BENCH

    echo "------4KB random write/read-----"
    output_file=$output_path/Rnd_NVM_4K
    WRITE80G-4K
    RUN_DB_BENCH

    echo "------16KB random write/read-----"
    output_file=$output_path/Rnd_NVM_16K
    WRITE80G-16K
    RUN_DB_BENCH

    echo "------64KB random write/read-----"
    output_file=$output_path/Rnd_NVM_64K
    WRITE80G-64K
    RUN_DB_BENCH


    benchmarks="fillseq,readseq,stats"
    # echo "------256B random write/read-----"
    # output_file=$output_path/Seq_NVM_256B
    # WRITE80G-256B
    # RUN_DB_BENCH

    echo "------1KB sequential write/read-----"
    output_file=$output_path/Seq_NVM_1K
    WRITE80G
    RUN_DB_BENCH

    echo "------4KB sequential write/read-----"
    output_file=$output_path/Seq_NVM_4K
    WRITE80G-4K
    RUN_DB_BENCH

    echo "------16KB sequential write/read-----"
    output_file=$output_path/Seq_NVM_16K
    WRITE80G-16K
    RUN_DB_BENCH

    echo "------64KB sequential write/read-----"
    output_file=$output_path/Seq_NVM_64K
    WRITE80G-64K
    RUN_DB_BENCH

    CLEAN_DB
}

DB_BENCH_THROUGHPUT() {
    echo "------------db_bench------------"
    benchmarks="fillrandom,stats"

    echo "------1K random write/read-----"
    output_file=$output_path/Throughput_Rnd_NVM_1KB
    WRITE80G-1KB-THROUGHPUT
    RUN_DB_BENCH

    echo "------4K random write/read-----"
    output_file=$output_path/Throughput_Rnd_NVM_4KB
    WRITE80G-4KB-THROUGHPUT
    RUN_DB_BENCH
    throughput=0

    CLEAN_DB
}

DB_BENCH_TEST_FLUSHSSD() {
    echo "----------db_bench_flushssd----------"
    benchmarks="fillrandom,readrandom,stats"
    echo "---8GNVM--4KB random write/read---"
    output_file=$output_path/NVM8G_Rnd_4K
    WRITE80G_8GNVM
    RUN_DB_BENCH

    echo "---16GNVM--4KB random write/read---"
    output_file=$output_path/NVM16G_Rnd_4K
    WRITE80G_16GNVM
    RUN_DB_BENCH

    echo "---32GNVM--4KB random write/read---"
    output_file=$output_path/NVM32G_Rnd_4K
    WRITE80G_32GNVM
    RUN_DB_BENCH

    echo "---64GNVM--4KB random write/read---"
    output_file=$output_path/NVM64G_Rnd_4K
    WRITE80G_64GNVM
    RUN_DB_BENCH

    flush_ssd=0
    leveldb_path=$pm_path;
    CLEAN_DB
}

YCSB_TEST(){
    cd $ycsb_path
    echo "------------YCSB------------"
    echo "-----1KB YCSB performance-----"
    output_file=$output_path/YCSB_1KB
    ycsb_input=1KB_ALL
    RUN_YCSB

    echo "-----4KB YCSB performance-----"
    output_file=$output_path/YCSB_4KB
    ycsb_input=4KB_ALL
    RUN_YCSB
    cd ..
}

YCSB_TEST_LATENCY(){
    cd $ycsb_path
    echo "------------YCSB------------"
    echo "-----1KB YCSB latency-----"
    output_file=$output_path/YCSB_1KB_Latency
    ycsb_input=1KB_ALL_Latency
    RUN_YCSB

    echo "-----4KB YCSB latency-----"
    output_file=$output_path/YCSB_4KB_Latency
    ycsb_input=4KB_ALL_Latency
    RUN_YCSB
    cd ..
}

YCSB_TEST_SSD(){
    cd $ycsb_path
    echo "------------YCSB------------"
    echo "-----1KB YCSB SSD-----"
    output_file=$output_path/YCSB_1KB_SSD
    ycsb_input=1KB_ALL_SSD
    RUN_YCSB

    echo "-----4KB YCSB SSD-----"
    output_file=$output_path/YCSB_4KB_SSD
    ycsb_input=4KB_ALL_SSD
    RUN_YCSB
    cd ..
}

CUCKOO_FILTER_ANALYSIS(){
    echo "------cuckoo filter analysis-------"
    benchmarks="fillseq,readwhilewriting,stats"
    echo "---- with cuckoo filter ----"
    sed -i 's/CUCKOO_FILTER = true/CUCKOO_FILTER = false/g' $db_path/util/global.h
    MAKE
    output_file=$output_path/Cuckoo_Filter_No_RW_NVM_4K
    WRITE80G-4K
    RUN_DB_BENCH

    echo "---- without cuckoo filter ----"
    sed -i 's/CUCKOO_FILTER = false/CUCKOO_FILTER = true/g' $db_path/util/global.h
    MAKE
    output_file=$output_path/Cuckoo_Filter_Yes_RW_NVM_4K
    WRITE80G-4K
    RUN_DB_BENCH
}

THREAD_COUNT_ANALYSIS(){
    echo "------thread count analysis-------"
    benchmarks="fillrandom,stats"
    echo "---- 1 thread ----"
    sed -i 's/TASK_COUNT = [0-9]*/TASK_COUNT = 1/g' $db_path/util/global.h
    MAKE
    output_file=$output_path/Thead_1_Rnd_W_8GNVM_4K
    WRITE80G_8GNVM
    RUN_DB_BENCH

    echo "---- 4 thread ----"
    sed -i 's/TASK_COUNT = [0-9]*/TASK_COUNT = 4/g' $db_path/util/global.h
    MAKE
    output_file=$output_path/Thead_4_Rnd_W_8GNVM_4K
    WRITE80G_8GNVM
    RUN_DB_BENCH

    echo "---- 8 thread ----"
    sed -i 's/TASK_COUNT = [0-9]*/TASK_COUNT = 8/g' $db_path/util/global.h
    MAKE
    output_file=$output_path/Thead_8_Rnd_W_8GNVM_4K
    WRITE80G_8GNVM
    RUN_DB_BENCH

    echo "---- 16 thread ----"
    sed -i 's/TASK_COUNT = [0-9]*/TASK_COUNT = 16/g' $db_path/util/global.h
    MAKE
    output_file=$output_path/Thead_16_Rnd_W_8GNVM_4K
    WRITE80G_8GNVM
    RUN_DB_BENCH

    echo "---- 32 thread ----"
    sed -i 's/TASK_COUNT = [0-9]*/TASK_COUNT = 32/g' $db_path/util/global.h
    MAKE
    output_file=$output_path/Thead_32_Rnd_W_8GNVM_4K
    WRITE80G_8GNVM
    RUN_DB_BENCH

    echo "---- 64 thread ----"
    sed -i 's/TASK_COUNT = [0-9]*/TASK_COUNT = 64/g' $db_path/util/global.h
    MAKE
    output_file=$output_path/Thead_64_Rnd_W_8GNVM_4K
    WRITE80G_8GNVM
    RUN_DB_BENCH

    flush_ssd=0
    leveldb_path=$pm_path;
}

function SMALL_VALUE_TEST(){
    echo "------data size analysis-------"
    benchmarks="fillrandom,readrandom,stats"
    num_kvs=$((100*$MB))

    echo "---- key100M_8B----"
    output_file=$output_path/key100M_8B
    value_size=$((8))
    RUN_DB_BENCH

    echo "---- key100M_32B----"
    output_file=$output_path/key100M_32B
    value_size=$((32))
    RUN_DB_BENCH

    echo "---- key100M_128B----"
    output_file=$output_path/key100M_128B
    value_size=$((128))
    RUN_DB_BENCH
}

MAKE
SET_OUTPUT_PATH

# echo "chapter 4.1"
# DB_BENCH_TEST
# DB_BENCH_THROUGHPUT

# echo "chapter 4.2"
# YCSB_TEST
# YCSB_TEST_LATENCY

SMALL_VALUE_TEST

CLEAN_DB
# sudo cp build/libleveldb.a /usr/local/lib/
# sudo cp -r include/leveldb /usr/local/include/
# -exec break __sanitizer::Die