%Inputs
Omega_min = 0.25; %Minimum frequency in Hz
Omega_max = 10; %Maximum frequency in Hz
T = 120; %Duration of testing in s
A = 1; %Constant amplitude of chirp (Units are dependent on what is being tested)
N = 10; %How many times the highest frequency we want to sample at must be at least 2 to prevent aliasing

%CSV Formating
File_name = 'Testing_Chirp';
effector = {'Amplitude'};

%Constants
C1 = 0.0187;
C2 = 4;

%Unit conversions
t = 0:1/(Omega_max*N):T; %Creates a time array that samples at a rate of N*omega_max per second
Omega_min = 2*pi*Omega_min; %Converts Omega_min from Hz to rad/s
Omega_max = 2*pi*Omega_max; %Converts Omega_max from Hz to rad/s

%Equations
%w_t = Omega_min + C2.*(exp(C1.*t./T) - 1)*(Omega_max - Omega_min); (Dont
%think I need this)

%Angle as a function of time
theta_t = Omega_min.*t + C2*(Omega_max - Omega_min)*((T/C1)*(exp(C1*t/T) - 1) - t);

%Chirp Waveform
Chirp = A*sin(theta_t);

%Creating csv file to use on drone

input = [t' Chirp']; %Inputs to be outputted to a table, concatenated 
% in line with the variable creation to create two columns

Table = array2table(input); %Creates a table out of the matrix created by input


%Formating the file
Table.Properties.VariableNames = ["Time", effector]; %Labels the table
File_name = sprintf([File_name '.csv']);

writetable(Table, File_name) %Writes the table to a csv file

%Questions:
%Is there a way to automate time period, such as a specification of N
%periods relating to each swept frequency

%For the chirp do we need to run it each time or does this formula allow
%for full charecterization of the responses

%I don't think we need w(t) since theta is just it integrated but just want
%to make sure.

%I would assume this is an exponential chirp, what are the advantages of
%this method?
