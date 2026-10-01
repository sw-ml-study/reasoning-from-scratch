-- Read-only Nsight 2026.5 SQLite analysis for cuda_profile_stages.mlpl.
-- Use completed DtoH API boundaries; windows include intervening MLPL overhead.
-- These are elapsed spans, not occupancy. Host and GPU columns overlap.
CREATE TEMP VIEW vector_copies AS
SELECT a.start AS api_start, a.end AS api_end, m.start AS copy_start,
       m.end AS copy_end,
       row_number() OVER (ORDER BY a.start)-1 AS ordinal,
       lag(a.end) OVER (ORDER BY a.start) AS previous_end
FROM CUPTI_ACTIVITY_KIND_MEMCPY m
JOIN CUPTI_ACTIVITY_KIND_RUNTIME a USING(correlationId)
JOIN StringIds s ON s.id=a.nameId
WHERE m.bytes=607744 AND m.copyKind=2 AND s.value='cuMemcpyDtoHAsync_v2';
CREATE TEMP VIEW decodes AS
SELECT *, ordinal/17 AS group_index, ordinal%17-1 AS iteration
FROM vector_copies WHERE ordinal<51 AND ordinal%17 BETWEEN 1 AND 16;
SELECT json_object(
 'group_index',d.group_index,'iteration',d.iteration,
 'window_ms',(d.api_end-d.previous_end)/1e6,
 'kernels',(SELECT count(*) FROM CUPTI_ACTIVITY_KIND_KERNEL k WHERE k.start>=d.previous_end AND k.end<=d.api_end),
 'kernel_span_ms',(SELECT sum(k.end-k.start)/1e6 FROM CUPTI_ACTIVITY_KIND_KERNEL k WHERE k.start>=d.previous_end AND k.end<=d.api_end),
 'launch_api_ms',(SELECT sum(a.end-a.start)/1e6 FROM CUPTI_ACTIVITY_KIND_RUNTIME a JOIN StringIds s ON s.id=a.nameId WHERE a.start>=d.previous_end AND a.end<=d.api_end AND s.value IN ('cuLaunchKernel','cuLaunchKernelEx')),
 'allocation_api_ms',(SELECT sum(a.end-a.start)/1e6 FROM CUPTI_ACTIVITY_KIND_RUNTIME a JOIN StringIds s ON s.id=a.nameId WHERE a.start>=d.previous_end AND a.end<=d.api_end AND s.value IN ('cuMemAllocAsync','cuMemFreeAsync')),
 'dtoh_api_ms',(d.api_end-d.api_start)/1e6,
 'dtoh_gpu_span_ms',(d.copy_end-d.copy_start)/1e6)
FROM decodes d ORDER BY d.ordinal;
