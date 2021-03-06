classdef pr_2wall
	properties
		m = 0.01
		I = 1.2
		nv
		v
		env_regions
		g = 9.8
		regions
		lines
		traj
		ext_f
		env
	end

	methods
		function obj = pr_2wall()
			obj.nv = 4;
			obj.v = [-1,-1;1,-1;1,1;-1,1]'/20;
			dt = 0.1;
			obj.I = obj.m*(0.1)^2/6;

			% trajectory
			y = 0.05 - 0.05*sin(linspace(0,-pi/8,5));
			x = 0.05 - 0.05*cos(linspace(0,-pi/8,5));
			
			th = [linspace(0,-pi/8,5)];

			for t = 1:5
				rot = [cos(th(t)),-sin(th(t));sin(th(t)),cos(th(t))];
				r(:,t) = [0.05;0.1] - rot*obj.v(:,3);
			end

			r0 = [linspace(-0.01,0,4);0.05*ones(1,4);linspace(0,0,4)];
			r1 = [r;th];

			obj.traj.r = [r0,r1];
			NT = size(obj.traj.r,2);
			obj.traj.dr = zeros(3,NT);
			obj.traj.ddr = zeros(3,NT);


			% derivatives
			for t = 2:NT-1
				obj.traj.dr(:,t) = (obj.traj.r(:,t+1)-obj.traj.r(:,t-1))/(dt);
			end

			for t = 1:NT
				if t > 1; v1 = obj.traj.r(:,t-1); else; v1 = obj.traj.r(:,t); end;
				if t < NT; v2 = obj.traj.r(:,t+1); else; v2 = obj.traj.r(:,t); end;

				obj.traj.ddr(:,t) = (-2*obj.traj.r(:,t)+v1+v2)/(dt)^2;
			end

			% external force constraints
			ext_f = {};
			ext_f{1} = struct(); ext_f{1}.fc1 = [-0.1,1]; ext_f{1}.fc2 = [.1,1];
			ext_f{2} = struct(); ext_f{2}.fc1 = [-1,-0.1]; ext_f{2}.fc2 = [-1,0.1];
			ext_f{3} = struct(); ext_f{3}.fc1 = [-1,-0.1]; ext_f{3}.fc2 = [-1,0.1];
			ext_f{4} = struct(); ext_f{4}.fc1 = [0,0]; ext_f{4}.fc2 = [0,0];

			% constraints for the entire plan
			obj.ext_f = {};

			for v = 1:4
				obj.ext_f{v} = struct();
				obj.ext_f{v}.fc1 = zeros(2,NT);
				obj.ext_f{v}.fc2 = zeros(2,NT);
				obj.ext_f{v}.jac = zeros(2,3,NT);
			end

			for t = 1:4
				for v = 1:2
					th = obj.traj.r(3,t);
					drot = 0.01/sqrt(2)*[cos(pi/4-th);sin(pi/4-th)];
					obj.ext_f{v}.fc1(:,t) = ext_f{v}.fc1;
					obj.ext_f{v}.fc2(:,t) = ext_f{v}.fc2;
					obj.ext_f{v}.jac(:,:,t) = 0*[eye(2), drot];
				end
			end

			for t = 5
				th = obj.traj.r(3,t);
				drot = 0.01/sqrt(2)*[cos(pi/4-th);sin(pi/4-th)];
				obj.ext_f{1}.fc1(:,t) = ext_f{1}.fc1;
				obj.ext_f{1}.fc2(:,t) = ext_f{1}.fc2;
				obj.ext_f{1}.jac(:,:,t) = 0*[eye(2), drot];

				obj.ext_f{2}.fc1(:,t) = ext_f{2}.fc1;
				obj.ext_f{2}.fc2(:,t) = ext_f{2}.fc2;
				obj.ext_f{2}.jac(:,:,t) = 0*[eye(2), drot];
			end

			for t = 5:9
				th = obj.traj.r(3,t);
				drot = 0.01/sqrt(2)*[cos(pi/4-th);sin(pi/4-th)];
				obj.ext_f{3}.fc1(:,t) = ext_f{3}.fc1;
				obj.ext_f{3}.fc2(:,t) = ext_f{3}.fc2;
				obj.ext_f{3}.jac(:,:,t) = 0*[eye(2), drot];
			end
			% cone edges

			% lines for reference
			lines_init = {};
			lines_init{1} = struct(); lines_init{1}.v1 = [-0.5,-0.5]'/10; lines_init{1}.v2 = [0.5,-0.5]'/10;
			lines_init{1}.fc1 = [0.5,1]'; lines_init{1}.fc2 = [-0.5,1]';
			lines_init{1}.t = [-1,0];

			lines_init{2} = struct(); lines_init{2}.v1 = [0.5,-0.5]'/10; lines_init{2}.v2 = [0.5,0.5]'/10;
			lines_init{2}.fc1 = [-2,1]'; lines_init{2}.fc2 = [-2,-1]';
			lines_init{2}.t = [0,-1];

			lines_init{3} = struct(); lines_init{3}.v1 = [0.5,0.5]'/10; lines_init{3}.v2 = [-0.5,0.5]'/10;
			lines_init{3}.fc1 = [1,-2]'; lines_init{3}.fc2 = [-1,-2]';
			lines_init{3}.t = [1,0];

			lines_init{4} = struct(); lines_init{4}.v1 = [-0.5,0.5]'/10; lines_init{4}.v2 = [-0.5,-0.5]'/10;
			lines_init{4}.fc1 = [2,-1]'; lines_init{4}.fc2 = [2,1]';
			lines_init{4}.t = [0,1];

			% lines for the entire plan
			obj.lines = {};

			% applies the transformation to each line segment
			for l = 1:obj.nv
				obj.lines{l} = struct();
				obj.lines{l}.v1 = zeros(2,NT);
				obj.lines{l}.v2 = zeros(2,NT);
				obj.lines{l}.fc1 = zeros(2,NT);
				obj.lines{l}.fc2 = zeros(2,NT);
				for t = 1:NT
					th = obj.traj.r(3,t); trans = obj.traj.r(1:2,t);
					rotmat = [cos(th),-sin(th);sin(th),cos(th)];
					obj.lines{l}.v1(:,t) = trans + rotmat*lines_init{l}.v1;
					obj.lines{l}.v2(:,t) = trans + rotmat*lines_init{l}.v2;

					obj.lines{l}.fc1(:,t) = rotmat*lines_init{l}.fc1;
					obj.lines{l}.fc2(:,t) = rotmat*lines_init{l}.fc2;
				end
			end

			% regions for reference
			regions_init = {};
			for i = 1:obj.nv
				idx_1 = i;
				idx_2 = i+1;
				if idx_2 > obj.nv; idx_2 = 1; end;
				regions_init{i} = struct(); 
				res = inv([obj.v(:,idx_1)';obj.v(:,idx_2)'])*[1;1];
				regions_init{i}.A = -res'; regions_init{i}.b = -1;
			end 

			% regions during the motion
			obj.regions = {};
			for r = 1:obj.nv
				obj.regions{r} = struct();
				obj.regions{r}.A = zeros(size(regions_init{r}.A,1),size(regions_init{r}.A,2),NT);
				obj.regions{r}.b = zeros(size(regions_init{r}.b,1),NT);
				% reorients the planes through time
				for t = 1:NT
					th = obj.traj.r(3,t); trans = obj.traj.r(1:2,t);
					rotmat = [cos(th),-sin(th);sin(th),cos(th)];
					obj.regions{r}.A(:,:,t) = regions_init{r}.A*inv(rotmat);
					obj.regions{r}.b(:,t) = regions_init{r}.b + regions_init{r}.A*inv(rotmat)*trans;
				end
			end	

			% environment regiions
			obj.env_regions = {}
			obj.env_regions{1}.A = [0,-1]; obj.env_regions{1}.b = -0.001;
			obj.env_regions{2}.A = [1,0];  obj.env_regions{2}.b = 0.049;

			% environment for drawing
			obj.env = {}; 
			obj.env{1}.x = [-1,1,1,-1]; obj.env{1}.y = [-1,-1,0,0];
			obj.env{1}.n = [0;1];
			obj.env{2}.x = [0.05,1,1,0.05]; obj.env{2}.y = [-1,-1,1,1]; 
			obj.env{2}.n = [-1;0];
		end
	end

end