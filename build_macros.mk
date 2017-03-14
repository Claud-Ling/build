# This table is used in converting lower case to upper case.
uppercase_table:=a,A b,B c,C d,D e,E f,F g,G h,H i,I j,J k,K l,L m,M n,N o,O p,P q,Q r,R s,S t,T u,U v,V w,W x,X y,Y z,Z

# Internal macro used for converting lower case to upper case.
#   $(1) = upper case table
#   $(2) = String to convert
define uppercase_internal
$(if $(1),$$(subst $(firstword $(1)),$(call uppercase_internal,$(wordlist 2,$(words $(1)),$(1)),$(2))),$(2))
endef

# A macro for converting a string to upper case
#   $(1) = String to convert
define uppercase
$(eval uppercase_result:=$(call uppercase_internal,$(uppercase_table),$(1)))$(uppercase_result)
endef

# This table is used in converting upper case to lower case.
lowercase_table:=A,a B,b C,c D,d E,e F,f G,g H,h I,i J,j K,k L,l M,m N,n O,o P,p Q,q R,r S,s T,t U,u V,v W,w X,x Y,y Z,z

# Internal macro used for converting upper case to lower case.
#   $(1) = lower case table
#   $(2) = String to convert
define lowercase_internal
$(if $(1),$$(subst $(firstword $(1)),$(call lowercase_internal,$(wordlist 2,$(words $(1)),$(1)),$(2))),$(2))
endef

# A macro for converting a string to lower case
#   $(1) = String to convert
define lowercase
$(eval lowercase_result:=$(call lowercase_internal,$(lowercase_table),$(1)))$(lowercase_result)
endef

# Convenience function for adding build definitions
# $(eval $(call add_define,FOO)) will have:
# -DFOO if $(FOO) is empty; -DFOO=$(FOO) otherwise
define add_define
    DEFINES			+=	-D$(1)$(if $(value $(1)),=$(value $(1)),)
endef

# Convenience function for adding build definitions
# $(eval $(call add_define_val,FOO,BAR)) will have:
# -DFOO=BAR
define add_define_val
    DEFINES			+=	-D$(1)=$(2)
endef

# Convenience function for verifying option has a boolean value
# $(eval $(call assert_boolean,FOO)) will assert FOO is 0 or 1
define assert_boolean
    $(and $(patsubst 0,,$(value $(1))),$(patsubst 1,,$(value $(1))),$(error $(1) must be boolean))
endef

###
# filechk is used to check if the content of a generated file is updated.
# Sample usage:
# define filechk_sample
#	echo $KERNELRELEASE
# endef
# version.h : Makefile
#	$(call filechk,sample)
# The rule defined shall write to stdout the content of the new file.
# The existing file will be compared with the new one.
# - If no file exist it is created
# - If the content differ the new file is used
# - If they are equal no change, and no timestamp update
# - stdin is piped in from the first prerequisite ($<) so one has
#   to specify a valid file as first prerequisite (often the kbuild file)
define filechk
	$(Q)set -e;				\
	echo '  CHK     $@';			\
	mkdir -p $(dir $@);			\
	$(filechk_$(1)) < $< > $@.tmp;		\
	if [ -r $@ ] && cmp -s $@ $@.tmp; then	\
		rm -f $@.tmp;			\
	else					\
		echo '  UPD     $@';		\
		mv -f $@.tmp $@;		\
	fi
endef

# macro to get git version info of specified directory
#   $1 = target directory
#
define git_version
$(shell set -e;	\
	cd $1 2>/dev/null;	\
	git describe --always --dirty 2>/dev/null || echo Unknown;	\
)
endef
