int print_args(int argc, char** argv);
void* __stack_chk_guard = (void*) 8242072231408251708;
__stack_chk_fail (void)
{
  // printf("stack smashing detected");
}


int main(int argc, char** argv)
{
    print_args(argc, argv);
    return 0;
}