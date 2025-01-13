# ODA Storage Scripts

This directory contains scripts for optimizing storage and cache management for Large Language Models (LLMs) and AI workloads on ZFS-based systems.

## Scripts

### oda-storage.sh

A comprehensive ZFS optimization script for LLM workloads that configures:

- ZFS ARC (Adaptive Replacement Cache) sizing
- L2ARC on SSD for second-level caching
- ZRAM configuration for compressed RAM
- Tmpfs-based model cache
- ZFS dataset optimizations
- Model preloading functionality
- Performance monitoring

#### Features:
- Automatic ARC sizing based on system RAM
- L2ARC configuration on SSD
- ZRAM setup for improved memory management
- Tmpfs mount for fast model cache access
- Comprehensive ZFS dataset optimizations
- Model preloading script generation
- Performance monitoring tools

#### Usage:
```bash
sudo ./oda-storage.sh
```
Follow the interactive prompts to configure your storage setup.

### model_cache.sh

A script for managing and optimizing Hugging Face model cache storage on ZFS. It helps migrate the cache to a different drive while applying optimal ZFS settings for LLM workloads.

#### Features:
- Migrates Hugging Face cache to a new location (e.g., secondary drive)
- Applies ZFS optimizations for LLM workloads:
  - Uses LZ4 compression
  - Sets 1M recordsize for large files
  - Disables atime for better performance
  - Configures primarycache=metadata for optimal caching
  - Sets logbias=throughput for better sequential performance
  - Enables xattr=sa for improved small file handling
- Performs integrity checks during migration
- Automatically updates shell configuration
- Verifies Python/Hugging Face integration

#### Usage:
```bash
./model_cache.sh
```

## ZFS Optimization Details

The scripts implement the following ZFS optimizations for LLM workloads:

1. **Memory Management**:
   - ARC sizing based on system RAM
   - L2ARC configuration for SSD caching
   - ZRAM for compressed memory
   - Tmpfs for high-speed cache access

2. **Dataset Optimizations**:
   - `recordsize=1M`: Optimal for large model files
   - `compression=lz4`: Efficient compression with low CPU overhead
   - `atime=off`: Reduces unnecessary writes
   - `primarycache=metadata`: Optimizes cache usage
   - `prefetch=1`: Enables prefetching for sequential reads
   - `logbias=throughput`: Optimizes for sequential operations
   - `xattr=sa`: Improves small file performance

3. **Performance Monitoring**:
   - ZFS cache statistics
   - IO statistics
   - Memory usage tracking
   - Virtual memory statistics

## Requirements

- ZFS filesystem
- Python3 (for model_cache.sh)
- Hugging Face Transformers library (for model_cache.sh)
- zfsutils-linux
- zram-config
- util-linux
- Basic system utilities (rsync, numfmt, etc.)

## Contributing

Feel free to open issues or submit pull requests with improvements or bug fixes.

## License

MIT License
