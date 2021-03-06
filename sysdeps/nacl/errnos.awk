# Script to produce bits/errno.h for NaCl.

# Copyright (C) 2015-2017 Free Software Foundation, Inc.
# This file is part of the GNU C Library.

# The GNU C Library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.

# The GNU C Library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public
# License along with the GNU C Library; if not, see
# <http://www.gnu.org/licenses/>.

BEGIN { maxerrno = 0 }

$1 == "#define" && $2 ~ /NACL_ABI_E[A-Z0-9_]+/ && $3 ~ /[0-9]+/ {
  ename = $2;
  sub(/NACL_ABI_/, "", ename);
  errno = $3 + 0;
  if (errno > maxerrno) maxerrno = errno;
  errnos[errno] = ename;
  errnos_by_name[ename] = errno;
  if ($4 == "/*" && !(ename in errno_text)) {
    etext = $5;
    for (i = 6; i <= NF && $i != "*/"; ++i)
      etext = etext " " $i;
    errno_text[ename] = etext;
  }
  next;
}

$1 == "@comment" && $2 == "errno.h" { errnoh=1; next }
errnoh == 1 && $1 == "@comment" {
  ++errnoh;
  etext = $3;
  for (i = 4; i <= NF; ++i)
    etext = etext " " $i;
  next;
}
errnoh == 2 && $1 == "@deftypevr" && $2 == "Macro" && $3 == "int" {
  ename = $4;
  errno_text[ename] = etext;
  next;
}

function define_errno(errno, ename) {
  etext = errno_text[ename];
  if (length(ename) < 8) ename = ename "\t";
  printf "#define\t%s\t%d\t/* %s */\n", ename, errno, etext;
}

END {
  print "\
/* This file generated by errnos.awk.  */\n\
\n\
#if !defined __Emath_defined && (defined _ERRNO_H || defined __need_Emath)\n\
#undef	__need_Emath\n\
#define	__Emath_defined	1";
  emath["EDOM"] = emath["EILSEQ"] = emath["ERANGE"] = 1;
  for (ename in emath) {
    errno = errnos_by_name[ename];
    define_errno(errno, ename);
    delete errnos[errno];
  }
  print "\
#endif\n\
\n\
#ifdef _ERRNO_H\n";

  for (i = 1; i <= maxerrno; ++i)
    if (i in errnos) define_errno(i, errnos[i]);

  print "\n\
#define	EWOULDBLOCK	EAGAIN\n\
#define	ENOTSUP		EOPNOTSUPP\n\
\n\
extern __thread int errno __attribute__ ((__tls_model__ (\"initial-exec\")));\n\
#define errno errno\n\
\n\
#endif";
}
