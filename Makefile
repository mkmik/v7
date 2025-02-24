WARNS = -W -Wall -pedantic -Wno-comment -Wno-variadic-macros
V7_FLAGS = -I./src -I.
CFLAGS = $(WARNS) -g -O0 -lm $(PROF) $(V7_FLAGS) $(CFLAGS_EXTRA)

SRC_DIR=src
TOP_SOURCES=$(addprefix $(SRC_DIR)/, $(SOURCES))
TOP_HEADERS=$(addprefix $(SRC_DIR)/, $(HEADERS))

CLANG:=clang

ifneq ("$(wildcard /usr/local/bin/clang-3.5)","")
	CLANG:=/usr/local/bin/clang-3.5
endif

include src/sources.mk

.PHONY: cpplint

all: v7 amalgamated_v7
	@$(MAKE) -C examples
	@$(MAKE) -C tests

v7.c: $(TOP_HEADERS) $(TOP_SOURCES) v7.h Makefile
	cat v7.h $(TOP_HEADERS) $(TOP_SOURCES) | sed -E "/#include .*(v7.h|`echo $(TOP_HEADERS) | sed -e 's,src/,,g' -e 's, ,|,g'`)/d" > $@

v: unit_test
	valgrind -q --leak-check=full --show-reachable=yes \
	--leak-resolution=high --num-callers=100 ./unit_test
#	valgrind -q --leak-check=full ./v7 tests/run_tests.js
#	gcov -a unit_test.c

xrun: unit_test
	$(CC) -W -Wall -I. -I./src src/tokenizer.c -DTEST_RUN -DV7_EXPOSE_PRIVATE -o t
	./t

run:
	@$(MAKE) -C tests compile test_c99

all_warnings: v7.c
	$(CC) v7.c tests/unit_test.c -o $@ -Weverything -Werror $(CFLAGS)
	./$@

v7: $(TOP_HEADERS) $(TOP_SOURCES) v7.h
	$(CC) $(TOP_SOURCES) -o $@ -DV7_EXE -DV7_EXPOSE_PRIVATE $(CFLAGS) -lm
#	$(CC) $(TOP_SOURCES) -o $@ -DV7_EXE $(CFLAGS) -lm

asan_v7:
	@$(CLANG) -fsanitize=address -fcolor-diagnostics -fno-common $(TOP_SOURCES) -o v7 -DV7_EXE -DV7_EXPOSE_PRIVATE $(CFLAGS) -lm
	@ASAN_SYMBOLIZER_PATH=/usr/local/bin/llvm-symbolizer-3.5 ASAN_OPTIONS=symbolize=1,detect_stack_use_after_return=1,strict_init_order=1 ./v7 $(V7_ARGS)

msan_v7:
	@$(CLANG) -fsanitize=memory -fcolor-diagnostics -fno-common -fsanitize-memory-track-origins $(TOP_SOURCES) -o v7 -DV7_EXE -DV7_EXPOSE_PRIVATE $(CFLAGS) -lm
	@ASAN_SYMBOLIZER_PATH=/usr/local/bin/llvm-symbolizer-3.5 ASAN_OPTIONS=symbolize=1 ./v7 $(V7_ARGS)

amalgamated_v7: v7.h v7.c
	$(CC) v7.c -o $@ -DV7_EXE -DV7_EXPOSE_PRIVATE $(CFLAGS) -lm

m32_v7: $(TOP_HEADERS) $(TOP_SOURCES) v7.h
	$(CC) $(TOP_SOURCES) -o v7 -DV7_EXE -DV7_EXPOSE_PRIVATE $(CFLAGS) -m32 -lm

w: v7.c
	wine cl v7.c /Zi -DV7_EXE -DV7_EXPOSE_PRIVATE
	wine cl tests/unit_test.c $(TOP_SOURCES) $(V7_FLAGS) /Zi -DV7_EXPOSE_PRIVATE

clean:
	@$(MAKE) -C tests clean
	@$(MAKE) -C examples clean
	rm -rf *.gc* *.dSYM *.exe *.obj *.pdb a.out u unit_test v7 amalgamated_v7 t

setup-hooks:
	for i in .hooks/*; do ln -s ../../.hooks/$$(basename $$i) .git/hooks; done

difftest:
	@TMP=`mktemp -t checkout-diff.XXXXXX`; \
	git diff v7.c  >$$TMP ; \
	if [ -s "$$TMP" ]; then echo found diffs in checkout:; git status -s;  exit 1; fi; \
	rm $$TMP

cpplint:
	@$(MAKE) -C tests cpplint

docker:
	@$(MAKE) -C tests docker
