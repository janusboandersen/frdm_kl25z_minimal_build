
// keep refs
// extern void *__fini_array_start, *__fini_array_end;

// __attribute__((used, section(".keep.fini_array_refs")))
// static void *keep_refs[] = {
//     (void *)&__fini_array_start,
//     (void *)&__fini_array_end,
// };

int main(void) {
    return 0;
}