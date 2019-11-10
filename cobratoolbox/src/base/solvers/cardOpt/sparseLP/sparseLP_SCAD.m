function solution = sparseLP_SCAD(constraint,params)
% DC programming for solving the sparse LP
% min   ||x||_0 subject to linear constraints
% The l0 norm is approximated by SCAD function.
% See "Le Thi et al., DC approximation approaches for sparse optimization,
% European Journal of Operational Research, 2014"
% http://dx.doi.org/10.1016/j.ejor.2014.11.031
% 
% solution = sparseLP_SCAD(constraint,params)
% 
% INPUT
% constraint                Structure containing the following fields describing the linear constraints
%       A                   m x n LHS matrix
%       b                   m x 1 RHS vector
%       lb                  n x 1 Lower bound vector
%       ub                  n x 1 Upper bound vector
%       csense              m x 1 Constraint senses, a string containting the constraint sense for
%                           each row in A ('E', equality, 'G' greater than, 'L' less than).
%
% OPTIONAL INPUTS
% params                    parameters structure
%       nbMaxIteration      stopping criteria - number maximal of iteration (Defaut value = 1000)
%       epsilon             stopping criteria - (Defaut value = 10e-6)
%       theta               parameter of the approximation (Defaut value = 0.5)
% 
% OUTPUT
% solution                  Structure containing the following fields
%       x                   n x 1 solution vector
%       stat                status
%                           1 =  Solution found
%                           2 =  Unbounded
%                           0 =  Infeasible
%                           -1=  Invalid input

% Hoai Minh Le	20/10/2015

stop = false;
solution.x = [];
solution.stat = 1;

% Check inputs
if nargin < 2
    params.nbMaxIteration = 1000;
    params.epsilon = 10e-6;
    params.theta   = 0.5;  
else
    if isfield(params,'nbMaxIteration') == 0
        params.nbMaxIteration = 1000;
    end
    
    if isfield(params,'epsilon') == 0
        params.epsilon = 10e-6;
    end

    if isfield(params,'theta') == 0
        params.theta   = 0.5;
    end        
end

if isfield(constraint,'A') == 0
    error('Error:LHS matrix is not defined');
    solution.stat = -1;
    return;
end
if isfield(constraint,'b') == 0
    error('RHS vector is not defined');
    solution.stat = -1;
    return;
end    
if isfield(constraint,'lb') == 0
    error('Lower bound vector is not defined');
    solution.stat = -1;
    return;
end    
if isfield(constraint,'ub') == 0
    error('Upper bound vector is not defined');
    solution.stat = -1;
    return;
end        
if isfield(constraint,'csense') == 0
    error('Constraint sense vector is not defined');
    solution.stat = -1;
    return;
end      


[nbMaxIteration,epsilon,theta] = deal(params.nbMaxIteration,params.epsilon,params.theta);
[A,b,lb,ub,csense] = deal(constraint.A,constraint.b,constraint.lb,constraint.ub,constraint.csense);

%Parameters
nbIteration = 0;
alpha = 3;
one_over_theta = 1/theta;
alpha_over_theta = alpha/theta;
[m,n] = size(constraint.A);

%Create the linear sub-programme that one needs to solve at each iteration, only its
%objective function changes, the constraints set remain.

% Define objective - variable (x,t)
obj = [zeros(n,1);theta*ones(n,1)];
    
% Constraints
% Ax <=b
% t >= x
% t >= -x
A2 = [A         sparse(m,n);
      speye(n)  -speye(n);
      -speye(n) -speye(n)];
b2 = [b; zeros(2*n,1)];
csense2 = [csense;repmat('L',2*n, 1)];
    
% Bound;
% lb <= x <= ub
% 0  <= t <= max(|lb|,|ub|)
lb2 = [lb;zeros(n,1)];
ub2 = [ub;max(abs(lb),abs(ub))];
    
%Define the linear sub-problem  
subLPproblem = struct('c',obj,'osense',1,'A',A2,'csense',csense2,'b',b2,'lb',lb2,'ub',ub2);

%Initialisation
x = zeros(n,1);
obj_old = sparseLP_SCAD_obj(x,theta,alpha);

%DCA
while nbIteration < nbMaxIteration && stop ~= true, 
    
    x_old = x;
        
    %Compute x_bar in subgradient of second DC component
    x_bar  = zeros(n,1);
    for i=1:n,
        if (abs(x(i)) > one_over_theta) && (abs(x(i)) < alpha_over_theta)
            x_bar(i) = sign(x(i))*2*theta*(theta*abs(x(i))-1) / (alpha*alpha-1);
        end
        if abs(x(i)) >= alpha_over_theta
            x_bar(i) = sign(x(i))*2*theta / (alpha+1);
        end
    end

    
    %Solve the linear sub-program to obtain new x
    [x,LPsolution] = sparseLP_SCAD_solveSubProblem(subLPproblem,x_bar,theta,alpha);
    
    switch LPsolution.stat
        case 0
            error('Problem infeasible !');
            solution.x = [];
            solution.stat = 0;
            stop = true;
        case 2
            error('Problem unbounded !');
            solution.x = [];
            solution.stat = 2;
            stop = true;
        case 1
            %Check stopping criterion 
            error_x = norm(x - x_old);
            obj_new = sparseLP_SCAD_obj(x,theta,alpha);
            error_obj = abs(obj_new - obj_old);
            if (error_x < epsilon) || (error_obj < epsilon)
                stop = true;
            else
                obj_old = obj_new;                
            end
            % Automatically update the approximation parameter theta
            if theta < 1000
                theta = theta * 1.5;
            end

             nbIteration = nbIteration + 1;
%             disp(strcat('DCA - Iteration: ',num2str(nbIteration)));
%             disp(strcat('Obj:',num2str(obj_new)));    
%             disp(strcat('Stopping criteria error: ',num2str(min(error_x,error_obj))));
%             disp('=================================');

    end   
end
if solution.stat == 1
    solution.x = x;
end

end

function [x,LPsolution] = sparseLP_SCAD_solveSubProblem(subLPproblem,x_bar,theta,alpha)
  
    n = length(x_bar);

    % Define objective - variable (x,t)
    subLPproblem.obj = [-x_bar;(2*theta/(alpha+1))*ones(n,1)];
        
    %Solve the linear problem  
    LPsolution = solveCobraLP(subLPproblem);
        
    if LPsolution.stat == 1
        x = LPsolution.full(1:n);
    else
        x = [];
    end

end

%Compute the objective function
function obj = sparseLP_SCAD_obj(x,theta,alpha)
    n = length(x);    
    one_over_theta = 1/theta;
    alpha_over_theta = alpha/theta;
    obj = 0;
    
    for i=1:n,
        if abs(x(i)) <= one_over_theta
            obj = obj + 2*theta*abs(x(i)) / (alpha+1);
        end
        if (abs(x(i)) > one_over_theta) && (abs(x(i)) < alpha_over_theta)
            obj = obj + (-theta*theta*x(i)*x(i)+2*alpha*theta*abs(x(i))-1) / (alpha*alpha-1);
        end
        if abs(x(i)) >= alpha_over_theta
            obj = obj + 1;
        end
    end
end

