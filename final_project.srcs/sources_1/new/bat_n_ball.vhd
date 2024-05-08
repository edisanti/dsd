LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY bat_n_ball IS
    PORT (
        v_sync : IN STD_LOGIC;
        pixel_row : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        pixel_col : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        bat_x : IN STD_LOGIC_VECTOR (10 DOWNTO 0); -- current bat x position
        serve : IN STD_LOGIC; -- initiates serve
        red : OUT STD_LOGIC;
        green : OUT STD_LOGIC;
        blue : OUT STD_LOGIC;
        SW : IN UNSIGNED (4 DOWNTO 0);
        score_display : OUT std_logic_vector(15 DOWNTO 0);
        lvl_display : OUT std_logic_vector (15 DOWNTO 0);
        lives_display: OUT std_logic_vector (15 DOWNTO 0)
    );
END bat_n_ball;

ARCHITECTURE Behavioral OF bat_n_ball IS
    CONSTANT bsize : INTEGER := 8; -- ball size in pixels
    SIGNAL bat_w : INTEGER := 40; -- bat width in pixels
    CONSTANT bat_h : INTEGER := 3; -- bat height in pixels
    SIGNAL score_counter : std_logic_vector (15 DOWNTO 0);
    SIGNAL score_counter_tmp : std_logic_vector(15 DOWNTO 0);
    SIGNAL score_counter_tmp1 : std_logic_vector(15 DOWNTO 0);
    SIGNAL lvl_counter : std_logic_vector (15 DOWNTO 0):= conv_std_logic_vector(1,16);
    SIGNAL lives : STD_LOGIC_VECTOR(15 DOWNTO 0) := conv_std_logic_vector(5,16);
    SIGNAL lives_tmp : INTEGER := 0;
    
    -- distance ball moves each frame    
    SIGNAL ball_speed : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR (4, 11); -- originally 10 downto 0 
    SIGNAL ball_speed1 : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR (1, 11);
    SIGNAL ball_on : STD_LOGIC; -- indicates whether ball is at current pixel position
    SIGNAL ball_on1: STD_LOGIC;
    SIGNAL bat_on : STD_LOGIC; -- indicates whether bat at over current pixel position
    SIGNAL game_on : STD_LOGIC := '0'; -- indicates whether ball is in play
    SIGNAL game_on1 : STD_LOGIC := '0';
    SIGNAL color_control : INTEGER := 0;
    signal life_control : INTEGER := 0;
    
    -- current ball position - intitialized to center of screen
    SIGNAL ball_x : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(400, 11);
    SIGNAL ball_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(300, 11);
    SIGNAL ball_x1 : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(400, 11);
    SIGNAL ball_y1 : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(300, 11);
    
    -- bat vertical position
    CONSTANT bat_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(500, 11);
    -- current ball motion - initialized to (+ ball_speed) pixels/frame in both X and Y directions
    SIGNAL ball_x_motion, ball_y_motion : STD_LOGIC_VECTOR(10 DOWNTO 0) := ball_speed;
    SIGNAL ball_x_motion1, ball_y_motion1 : STD_LOGIC_VECTOR(10 DOWNTO 0) := ball_speed;
BEGIN
    score_display <= score_counter;
    lives_display <= lives;
    lvl_display <= lvl_counter;

    cball : PROCESS (color_control, bat_on) IS
    BEGIN
    
    IF color_control = 0 THEN
        red <= NOT bat_on;
        green <= NOT (ball_on OR ball_on1);
        blue <= NOT (ball_on OR ball_on1);
    ELSIF color_control = 1 THEN
        red <= NOT (ball_on OR ball_on1);
        green <= NOT bat_on;
        blue <= NOT bat_on;
    ELSIF color_control = 2 THEN
        red <= NOT bat_on;
        green <= NOT (ball_on OR ball_on1);
        blue <= NOT bat_on;
        
    END IF;

    END PROCESS;
    
    -- process to draw round ball
    -- set ball_on if current pixel address is covered by ball position
    balldraw : PROCESS (ball_x, ball_y, ball_x1, ball_y1, pixel_row, pixel_col) IS
        VARIABLE vx, vy : STD_LOGIC_VECTOR (10 DOWNTO 0); -- 9 downto 0
    BEGIN
        IF pixel_col <= ball_x THEN -- vx = |ball_x - pixel_col|
            vx := ball_x - pixel_col;
        ELSE
            vx := pixel_col - ball_x;
        END IF;
        IF pixel_row <= ball_y THEN -- vy = |ball_y - pixel_row|
            vy := ball_y - pixel_row;
        ELSE
            vy := pixel_row - ball_y;
        END IF;
        IF ((vx * vx) + (vy * vy)) < (bsize * bsize) THEN -- test if radial distance < bsize
            ball_on <= game_on;
        ELSE
            ball_on <= '0';
        END IF;
        
        -- second ball
        IF pixel_col <= ball_x1 THEN -- vx = |ball_x - pixel_col|
            vx := ball_x1 - pixel_col;
        ELSE
            vx := pixel_col - ball_x1;
        END IF;
        IF pixel_row <= ball_y1 THEN -- vy = |ball_y - pixel_row|
            vy := ball_y1 - pixel_row;
        ELSE
            vy := pixel_row - ball_y1;
        END IF;
        IF ((vx * vx) + (vy * vy)) < (bsize * bsize) THEN -- test if radial distance < bsize
            ball_on1 <= game_on1;
        ELSE
            ball_on1 <= '0';
        END IF;
        
    END PROCESS;
    -- process to draw bat
    -- set bat_on if current pixel address is covered by bat position
    batdraw : PROCESS (bat_x, pixel_row, pixel_col) IS
        VARIABLE vx, vy : STD_LOGIC_VECTOR (10 DOWNTO 0); -- 9 downto 0
    BEGIN
        IF ((pixel_col >= bat_x - bat_w) OR (bat_x <= bat_w)) AND
         pixel_col <= bat_x + bat_w AND
             pixel_row >= bat_y - bat_h AND
             pixel_row <= bat_y + bat_h THEN
                bat_on <= '1';
        ELSE
            bat_on <= '0';
        END IF;
    END PROCESS;
    -- process to move ball once every frame (i.e., once every vsync pulse)
    mball : PROCESS
        VARIABLE temp : STD_LOGIC_VECTOR (11 DOWNTO 0);
    BEGIN

        WAIT UNTIL rising_edge(v_sync);
        
        IF serve = '1' AND game_on = '0' THEN -- test for new serve
            
            game_on <= '1';
            ball_x_motion <= (NOT ball_speed) + 1;
            ball_y_motion <= (NOT ball_speed) + 1; -- set vspeed to (- ball_speed) pixels
            score_counter_tmp <= "0000000000000000";
            score_counter_tmp1 <= "0000000000000000";
            lives_tmp <= 0;
            
            IF lvl_counter >= "0000000000000011" THEN
                game_on1 <= '1';
                ball_x_motion1 <= (NOT ball_speed1) + 1;
                ball_y_motion1 <= (NOT ball_speed1) + 1;
            END IF;
            
            IF color_control = 1 THEN
                color_control <= 0; 
            END IF;
            
        ELSIF ball_y <= bsize THEN -- bounce off top wall
            ball_y_motion <= ball_speed; -- set vspeed to (+ ball_speed) pixels
            score_counter_tmp <= "0000000000000000";
            lives_tmp <= 0;
        
        ELSIF ball_y1 <= bsize THEN -- bounce off top wall
            ball_y_motion1 <= ball_speed; -- set vspeed to (+ ball_speed) pixels
            score_counter_tmp1 <= "0000000000000000";
            lives_tmp <= 0;
            
        ELSIF ball_y + bsize >= 600 AND lives_tmp = 0 THEN -- if ball meets bottom wall
            ball_y_motion <= (NOT ball_speed) + 1; -- set vspeed to (- ball_speed) pixels
            life_control <= 1;
            lives_tmp <= 1;
            lives_tmp <= 0;
            game_on <= '0'; -- and make ball disappear
            game_on1 <= '0';
            score_counter_tmp <= "0000000000000000";
            
        ELSIF ball_y1 + bsize >= 600 AND lives_tmp = 0 THEN -- if ball meets bottom wall
            ball_y_motion1 <= (NOT ball_speed) + 1; -- set vspeed to (- ball_speed) pixels
            life_control <= 1;
            lives_tmp <= 1;
            lives_tmp <= 0;
            game_on1 <= '0'; -- and make ball disappear
            game_on <= '0';
            score_counter_tmp1 <= "0000000000000000";
            
        END IF;
        
      IF life_control = 1 THEN
        lives <= lives - "0000000000000001";
         IF lives = "0000000000000001" THEN
            ball_speed <= "00000000100";
            ball_speed1 <= "00000000000";
            bat_w <= 40;
            score_counter <= "0000000000000000";
            lvl_counter <= "0000000000000001";
            lives <= "0000000000000101"; --5
            color_control <= 1;
           END IF;
        life_control <= 0;
        END IF;
        
        -- allow for bounce off left or right of screen
        IF ball_x + bsize >= 800 THEN -- bounce off right wall
            ball_x_motion <= (NOT ball_speed) + 1; -- set hspeed to (- ball_speed) pixels
            score_counter_tmp <= "0000000000000000";
            lives_tmp <= 0;
        ELSIF ball_x <= bsize THEN -- bounce off left wall
            score_counter_tmp <= "0000000000000000";
            lives_tmp <= 0;
            ball_x_motion <= ball_speed; -- set hspeed to (+ ball_speed) pixels
        END IF;
        
        IF ball_x1 + bsize >= 800 THEN -- bounce off right wall
            ball_x_motion1 <= (NOT ball_speed1) + 1; -- set hspeed to (- ball_speed) pixels
            score_counter_tmp1 <= "0000000000000000";
            lives_tmp <= 0;
        ELSIF ball_x1 <= bsize THEN -- bounce off left wall
            score_counter_tmp1 <= "0000000000000000";
            lives_tmp <= 0;
            ball_x_motion1 <= ball_speed1; -- set hspeed to (+ ball_speed) pixels
        END IF;
        
        
        -- allow for bounce off bat
        IF (ball_x + bsize/2) >= (bat_x - bat_w) AND
           (ball_x - bsize/2) <= (bat_x + bat_w) AND
             (ball_y + bsize/2) >= (bat_y - bat_h) AND
             (ball_y - bsize/2) <= (bat_y + bat_h) AND 
              score_counter_tmp <= "0000000000000000" THEN
                ball_y_motion <= (NOT ball_speed) + 1; -- set vspeed to (- ball_speed) pixels
                score_counter_tmp <= "1111111111111111";
                lives_tmp <= 0;
                score_counter <= score_counter + "0000000000000001";
                
                IF score_counter = "0000000000000010" THEN
                    score_counter <= "0000000000000000";
                    lvl_counter <= lvl_counter + "0000000000000001";
                    IF lvl_counter = "0000000000000010" THEN
                        bat_w <= 80;
                        ball_speed <= "00000000001";
                        ball_speed1 <= "00000000001";
                        game_on1 <= '1';
                        ball_x_motion1 <= (NOT ball_speed1) + 1;
                        ball_y_motion1 <= (NOT ball_speed1) + 1;
                    END IF;

                    ball_speed <= ball_speed + "00000000001";
                    ball_speed1 <= ball_speed1 + "00000000001";
                    IF color_control = 0 THEN
                        color_control <= 2;
                    ELSIF color_control = 2 THEN
                        color_control <= 0;
                    END IF;
                END IF;             
        END IF;
        
        IF (ball_x1 + bsize/2) >= (bat_x - bat_w) AND
           (ball_x1 - bsize/2) <= (bat_x + bat_w) AND
             (ball_y1 + bsize/2) >= (bat_y - bat_h) AND
             (ball_y1 - bsize/2) <= (bat_y + bat_h) AND 
              score_counter_tmp1 <= "0000000000000000" THEN
                ball_y_motion1 <= (NOT ball_speed1) + 1;
                score_counter_tmp1 <= "1111111111111111";
                lives_tmp <= 0;
                score_counter <= score_counter + "0000000000000001";
                
                IF score_counter = "0000000000000010" THEN
                    score_counter <= "0000000000000000";
                    lvl_counter <= lvl_counter + "0000000000000001";
                    ball_speed1 <= ball_speed1 + "00000000001";
                    IF color_control = 0 THEN
                        color_control <= 2;
                    ELSIF color_control = 2 THEN
                        color_control <= 0;
                    END IF;
                END IF;             
        END IF;
        

        -- compute next ball vertical position
        -- variable temp adds one more bit to calculation to fix unsigned underflow problems
        -- when ball_y is close to zero and ball_y_motion is negative
        temp := ('0' & ball_y) + (ball_y_motion(10) & ball_y_motion);
        IF game_on = '0' THEN
            ball_y <= CONV_STD_LOGIC_VECTOR(440, 11);
        ELSIF temp(11) = '1' THEN
            ball_y <= (OTHERS => '0');
        ELSE ball_y <= temp(10 DOWNTO 0); -- 9 downto 0
        END IF;
        -- compute next ball horizontal position
        -- variable temp adds one more bit to calculation to fix unsigned underflow problems
        -- when ball_x is close to zero and ball_x_motion is negative
        temp := ('0' & ball_x) + (ball_x_motion(10) & ball_x_motion);
        IF temp(11) = '1' THEN
            ball_x <= (OTHERS => '0');
        ELSE ball_x <= temp(10 DOWNTO 0);
        END IF;
        
        -- second ball position
        
         -- compute next ball vertical position
        -- variable temp adds one more bit to calculation to fix unsigned underflow problems
        -- when ball_y is close to zero and ball_y_motion is negative
        temp := ('0' & ball_y1) + (ball_y_motion1(10) & ball_y_motion1);
        IF game_on1 = '0' THEN
            ball_y1 <= CONV_STD_LOGIC_VECTOR(440, 11);
        ELSIF temp(11) = '1' THEN
            ball_y1 <= (OTHERS => '0');
        ELSE ball_y1 <= temp(10 DOWNTO 0); -- 9 downto 0
        END IF;
        -- compute next ball horizontal position
        -- variable temp adds one more bit to calculation to fix unsigned underflow problems
        -- when ball_x is close to zero and ball_x_motion is negative
        temp := ('0' & ball_x1) + (ball_x_motion1(10) & ball_x_motion1);
        IF temp(11) = '1' THEN
            ball_x1 <= (OTHERS => '0');
        ELSE ball_x1 <= temp(10 DOWNTO 0);
        END IF;
    END PROCESS;
    
END Behavioral;
