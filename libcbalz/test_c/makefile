LDLIBS = -L.. -lcbalz -Wl,-rpath=..

LDFLAGS += -no-pie -g

CFLAGS += -I.. -no-pie -g


OBJS = test.o

test: $(OBJS)

.PHONY: clean
clean:
	$(RM) $(OBJS)

