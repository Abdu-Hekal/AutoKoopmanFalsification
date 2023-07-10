function [F,P,O] = vector_KoopmanMilpRobust(phi,kList,kMax,ts,var,M)
% vector_KoopmanMilpRobust  constructs MILP constraints in YALMIP that compute
%                  the robustness of satisfaction for specification phi
%
% Input:
%       phi:    an STLformula
%       kList:  a list of time steps at which the formula is to be enforced
%       kMAx:   the length of the trajectory
%       ts:     the interval (in seconds) used for discretizing time
%       var:    a dictionary mapping strings to variables
%       M:   	a large positive constant used for big-M constraints
%       normz:  normalization values based on boundaries of reachable sets
%
% Output:
%       F:  YALMIP constraints
%       P:  a struct containing YALMIP decision variables representing
%           the quantitative satisfaction of phi over each time step in
%           kList
%       O:  a struct containing YALMIP parameter variables representing the
%       offset for each inequality.
%
% :copyright: TBD
% :license: TBD

if (nargin==4)
    M = 1000;
end

F = [];
P = [];
O = [];

if ischar(phi.interval)
    interval = [str2num(phi.interval)];
else
    interval = phi.interval;
end

a = interval(1);
b = interval(2);

a = max([0 floor(a/ts)]);
b = ceil(b/ts);

if b==Inf
    b = kMax;
end

switch (phi.type)
    case 'predicate'
        [F,P,O] = pred(phi.st,kList,var);

    case 'not'
        [Frest,Prest,Orest] = vector_KoopmanMilpRobust(phi.phi,kList,kMax,ts, var,M);
        [Fnot, Pnot] = not(Prest);
        F = [F, Fnot, Frest];
        P = Pnot;
        O = [O, Orest];

    case 'or'
        [Fdis1,Pdis1,O1] = vector_KoopmanMilpRobust(phi.phi1,kList,kMax,ts, var,M);
        [Fdis2,Pdis2,O2] = vector_KoopmanMilpRobust(phi.phi2,kList,kMax,ts, var,M);
        [For, Por] = or([Pdis1;Pdis2],M);
        F = [F, For, Fdis1, Fdis2];
        P = Por;
        O = [O, O1, O2];

    case 'and'
        [Fcon1,Pcon1,O1] = vector_KoopmanMilpRobust(phi.phi1,kList,kMax,ts, var,M);
        [Fcon2,Pcon2,O2] = vector_KoopmanMilpRobust(phi.phi2,kList,kMax,ts, var,M);
        [Fand, Pand] = and([Pcon1;Pcon2],M);
        F = [F, Fand, Fcon1, Fcon2];
        P = Pand;
        O = [O, O1, O2];

    case '=>'
        [Fant,Pant,O1] = vector_KoopmanMilpRobust(phi.phi1,kList,kMax,ts,var,M);
        [Fcons,Pcons,O2] = vector_KoopmanMilpRobust(phi.phi2,kList,kMax,ts, var,M);
        [Fnotant,Pnotant] = not(Pant);
        [Fimp, Pimp] = or([Pnotant;Pcons],M);
        F = [F, Fant, Fnotant, Fcons, Fimp];
        P = [Pimp,P];
        O = [O, O1, O2];

    case 'always'
        kListAlw = unique(cell2mat(arrayfun(@(k) {min(kMax,k + a): min(kMax,k + b)}, kList)));
        [Frest,Prest,Orest] = vector_KoopmanMilpRobust(phi.phi,kListAlw,kMax,ts, var,M);
        [Falw, Palw] = always(Prest,a,b,kList,kMax,M);
        F = [F, Falw];
        P = [Palw, P];
        F = [F, Frest];
        O = [O, Orest];

    case 'eventually'
        kListEv = unique(cell2mat(arrayfun(@(k) {min(kMax,k + a): min(kMax,k + b)}, kList)));
        [Frest,Prest,Orest] = vector_KoopmanMilpRobust(phi.phi,kListEv,kMax,ts, var,M);
        [Fev, Pev] = eventually(Prest,a,b,kList,kMax,M);
        F = [F, Fev];
        P = [Pev, P];
        F = [F, Frest];
        O = [O, Orest];

    case 'until'
        [Fp,Pp,O1] = vector_KoopmanMilpRobust(phi.phi1,kList,kMax,ts, var,M);
        [Fq,Pq,O2] = vector_KoopmanMilpRobust(phi.phi2,kList,kMax,ts, var,M);
        [Funtil, Puntil] = until(Pp,Pq,a,b,kList,kMax,M);
        F = [F, Funtil, Fp, Fq];
        P = Puntil;
        O = [O, O1, O2];

end
end

function [F,z,robOffset] = pred(st,kList,var)
% Enforce constraints based on predicates
% var is the variable dictionary
fnames = fieldnames(var);

for ifield= 1:numel(fnames)
    eval([ fnames{ifield} '= var.' fnames{ifield} ';']);
end

robOffset=sdpvar(1,1); %setup rob offset
st = regexprep(st,'\[t\]','\(t\)'); % Breach compatibility
if strfind(st, '<')
    tokens = regexp(st, '(.+)\s*<\s*(.+)','tokens');
    st = ['-(' tokens{1}{1} '- (' tokens{1}{2} ')+robOffset)'];
end
if strfind(st, '>')
    tokens = regexp(st, '(.+)\s*>\s*(.+)','tokens');
    st= [ '(' tokens{1}{1} ')-(' tokens{1}{2} ')+robOffset' ];
end
t_st = regexprep(st,'\<t\>',sprintf('%d:%d', kList(1),kList(end)));
try
    z_eval = eval(t_st);
end
zl = sdpvar(1,size(z_eval,2));
F = zl == z_eval;
z = zl;
end

% BOOLEAN OPERATIONS

function [F,P] = and(p_list,M)
[F,P] = min_r(p_list,M);
end


function [F,P] = or(p_list,M)
[F,P] = max_r(p_list,M);
end


function [F,P] = not(p_list)
k = size(p_list,2);
m = size(p_list,1);
P = sdpvar(1,k);
F = [P(:) == -p_list(:)];
end


% TEMPORAL OPERATIONS

function [F,P_alw] = always(P, a,b,kList,kMax,M)
F = [];
k = size(kList,2);
P_alw = sdpvar(1,k);
kListAlw = unique(cell2mat(arrayfun(@(k) {min(kMax,k + a) : min(kMax,k + b)}, kList)));

[ia, ib] = getIndices(kList(1:k),a,b,kMax);
ia_real = arrayfun(@(x) find(kListAlw==x, 1, 'first'), ia);
ib_real = arrayfun(@(x) find(kListAlw==x, 1, 'first'), ib);
max_size=size(unique(ib_real),2); %basically up to kmax, TODO: check this
iaib_cell = arrayfun(@(x, y) x:y, ia_real(1:max_size), ib_real(1:max_size), 'UniformOutput', false);
iaib_matrix = reshape(cell2mat(iaib_cell),max_size,[]);
[F0,P0] = and(P(iaib_matrix)',M);
F = [F;F0,P_alw(1:max_size)==P0];

end


function [F,P_ev] = eventually(P, a,b,kList,kMax,M)
k = size(kList,2);
P_ev = sdpvar(1,k);
kListEv = unique(cell2mat(arrayfun(@(k) {min(kMax,k + a) : min(kMax,k + b)}, kList)));

[ia, ib] = getIndices(1:k,a,b,kMax);
ia_real = arrayfun(@(x) find(kListEv==x, 1, 'first'), ia);
ib_real = arrayfun(@(x) find(kListEv==x, 1, 'first'), ib);
max_size=size(unique(ib_real),2); %basically up to kmax, TODO: check this
iaib_cell = arrayfun(@(x, y) x:y, ia_real(1:max_size), ib_real(1:max_size), 'UniformOutput', false);
iaib_matrix = reshape(cell2mat(iaib_cell),max_size,[]);
[F0,P0] = or(P(iaib_matrix)',M);
F = [F0,P_ev(1:max_size)==P0];

end


function [F,P_until] = until(Pp,Pq,a,b,k,M)

F = [];
P_until = sdpvar(1,k);

for i = 1:k
    [ia, ib] = getIndices(i,a,b,kMax);
    F0 = [];
    P0 = [];
    for j = ia:ib
        [F1,P1] = until_mins(i,j,Pp,Pq,M);
        F0 = [F0, F1];
        P0 = [P0, P1];
    end
    [F4,P4] = max_r(P0);
    F = [F;F0,F4,P_until(i)==P4];
end

end


% UTILITY FUNCTIONS

function [F,P] = min_r(p_list,M)

k = size(p_list,2);
m = size(p_list,1);

P = sdpvar(1,k);
z = binvar(m,k);

repP=repmat(P,m,1);

F = [sum(z,1) == ones(1,k)];
F = [F, repP <= p_list];
F = [F, p_list - (1-z)*M <= repP <= p_list + (1-z)*M];
end

function [F,P] = max_r(p_list,M)

k = size(p_list,2);
m = size(p_list,1);

P = sdpvar(1,k);
z = binvar(m,k);

F = [sum(z,1) == ones(1,k)];

repP=repmat(P,m,1);
F = [F, repP >= p_list];
F = [F, p_list - (1-z)*M <= repP <= p_list + (1-z)*M];

end

function [F,P] = until_mins(i,j,Pp,Pq,M)
[F0,P0] = min_r(Pp(i:j)',M);
[F1,P] = min_r([Pq(j),P0],M);
F = [F0,F1];
end

function [ia, ib] = getIndices(i,a,b,k)
ia = min(k,i+a);
ib = min(k,i+b);
end



