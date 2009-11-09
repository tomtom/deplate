<?php
/**
 * page-comments.inc.php
 * @author   Tom Link (micathom AT gmail com)
 * @license  GPL (see http://www.gnu.org/licenses/gpl.txt)
 * @created  21-Apr-2006.
 * @date     2009-11-09.
 * @version  0.101
 *
 * TODO:
 * - MySQL backend
 * - Login
 * - User interface (edit own messages)
 * - Admin interface (delete, edit messages)
 */


@include('page-comment.cfg.php');

if (!defined(PAGE_COMMENT_BACKEND))
    define('PAGE_COMMENT_BACKEND', '{arg default=file: commentBackend}');

#IF: commentBackend==mysql
if (!defined(PAGE_COMMENT_MYSQL_HOST))
    define('PAGE_COMMENT_MYSQL_HOST', '{arg default=localhost: commentDbHost}');

if (!defined(PAGE_COMMENT_MYSQL_USER))
    define('PAGE_COMMENT_MYSQL_USER', '{arg default=user: commentDbUser}');

if (!defined(PAGE_COMMENT_MYSQL_PW))
    define('PAGE_COMMENT_MYSQL_PW', '{arg: commentDbPassword}');

function page_comment_commit_mysql($page, $def) {
    // <+TBD+>
}

function page_comment_retrieve_mysql($page) {
    // <+TBD+>
}

#ELSE
if (!defined(PAGE_COMMENT_FDIR))
    define('PAGE_COMMENT_FDIR', '{arg default=%s__comments: commentFdir}');

function page_comment_commit_file($page, $def) {
    $def  = serialize($def);
    $mid  = page_comment_msg_id();
    $pdir = sprintf(PAGE_COMMENT_FDIR, $page);
    $fn   = "$pdir/$mid";
    if (!is_file($fn)) {
        if (!is_dir($pdir))
            mkdir($pdir);
        $h = fopen($fn, 'w');
        if ($h) {
            fwrite($h, $def);
            fclose($h);
            return $mid;
        }
    }
    return null;
}

function page_comment_retrieve_file($page) {
    $pdir = sprintf(PAGE_COMMENT_FDIR, $page);
    if (is_dir($pdir)) {
        $h = opendir($pdir);
        while ($file = readdir($h)) { 
            if ($file != '.' && $file != '..') { 
                $def = file_get_contents("$pdir/$file");
                $def = unserialize($def);
                $idx = $def['date'];
                $comments[$idx] = $def;
            } 
        }
        closedir($h);

        ksort($comments);
        return $comments;
    }
}

#ENDIF


function page_comment_form($page) {
    ?>
<div class="comment_form">
    <form action="" name="comment" method="post">
        <input type="hidden" name="page" value="<?php echo page_comment_id($page);?>">
        <table class="comment_form">
            <tr class="comment_form">
                <td class="comment_form">{msg: Name}:</td>
                <td class="comment_form"><input type="text" name="name" value="" size="50" maxlength="50" /></td>
            </tr>
            <tr class="comment_form">
                <td class="comment_form">{msg: E-Mail}:</td>
                <td class="comment_form"><input type="text" name="email" value="" size="50" maxlength="50" /></td>
            </tr>
            <tr class="comment_form">
                <td class="comment_form">{msg: Subject}:</td>
                <td class="comment_form"><input type="text" name="subject" value="" size="50" maxlength="30" /></td>
            </tr>
            <tr>
                <td class="comment_form">{msg: Comment}:</td>
                <td class="comment_form"><textarea name="text" cols="70" rows="8"></textarea></td>
            </tr>
            <tr class="comment_form">
                <td class="comment_form">&nbsp;</td>
                <td class="comment_form">
                    <button name="submit" value="<?php echo $page;?>" type="submit">{msg: Submit}</button>
                    <button name="reset" type="reset">{msg: Cancel}</button>
                </td>
            </tr>
        </table>
    </form>
</div>
<?php
}

function page_comment_view($def) {
    $name  = htmlentities($def['name']);
    $email = htmlentities($def['email']);
    $subj  = htmlentities($def['subject']);
    $date  = $def['date'];
    $text  = str_replace("\\n", "<br/>\\n", htmlentities($def['text']));
    echo <<<EOT
<div class="comment">
    <div class="comment_title">
        <span class="comment_author">$name</span>
        <span class="comment_subject">$subj</span>
EOT;
    if ($date) {
        // $date = strftime('%x %X', $date);
        $date = strftime('%d. %B %y, %X', $date);
        echo <<<EOT
        <br/><span class="comment_date">$date</span>
EOT;
    }
    echo <<<EOT
    </div>
    <div class="comment_text">
        $text
    </div>
</div>
EOT;
}

function page_comment_list($page) {
    $fn       = 'page_comment_retrieve_'. PAGE_COMMENT_BACKEND;
    $comments = $fn($page);
    if ($comments) {
        foreach($comments as $def) {
            page_comment_view($def);
        }
    }
}

/**
 * Get the message ID
 */
function page_comment_msg_id() {
    global $r_name, $r_email, $r_submit, $r_text, $r_subject;
    return md5("$r_name\\n$r_email\\n$r_subject\\n$r_text");
}

/**
 * Get an ID for a page name
 */
function page_comment_id($page) {
    // <+TBD+> encrypt/hash: date + salt + page name
    return $page;
}

/**
 * List comments and view an entry form.
 */
function page_comment($page) {
    #IF: commentLocale
    setlocale(LC_ALL, "{arg: commentLocale}");
    #ENDIF
    import_request_variables('p', 'r_');
    global $r_page, $r_name, $r_email, $r_submit, $r_text, $r_subject;

    // if ($r_submit === $page and $r_text) {
    if ($r_submit and $r_page === page_comment_id($page) and $r_text) {
        if (!$r_name)
            $r_name = "{msg: Anonymous}";
        $def = array(
            'name'         => $r_name,
            'email'        => $r_email,
            'subject'      => $r_subject,
            'text'         => $r_text,
            'date'         => time(),
            'user_ip'      => getenv('REMOTE_ADDR'),
            'user_host'    => getenv('REMOTE_HOST'),
            'user_ref'     => getenv('HTTP_REFERER'),
            'user_agent'   => getenv('HTTP_USER_AGENT'),
            'user_request' => getenv('REQUEST_URI'),
        );
        $fn = 'page_comment_commit_'. PAGE_COMMENT_BACKEND;
        if ($mid = $fn($page, $def)) {
            $email = '{arg: commentEmail}';
            if ($email) {
                $subj = sprintf('{arg default=[Comment] %s -- %s: commentSubject}',
                    $page, $mid);
                @mail($email, $subj, var_export($def, true), 
                    "From: $email\\r\\nX-Mailer: PHP/" . phpversion());
            }
        }
    }

    page_comment_list($page);
    
    page_comment_form($page);
}
?>
