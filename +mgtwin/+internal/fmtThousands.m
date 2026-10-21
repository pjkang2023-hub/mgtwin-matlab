function s = fmtThousands(x)
%FMTTHOUSANDS Python "{x:,.0f}" -- integer with thousands separators.
s = sprintf("%.0f", x);
neg = startsWith(s, "-");
if neg, s = extractAfter(s, 1); end
c = char(s);
out = "";
while numel(c) > 3
    out = "," + string(c(end-2:end)) + out;
    c = c(1:end-3);
end
out = string(c) + out;
if neg, out = "-" + out; end
s = out;
end
